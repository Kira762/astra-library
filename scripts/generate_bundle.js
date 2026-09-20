#!/usr/bin/env node
/**
 * Wax-style bundle generator for Astra.
 *
 * Regenerates `version-1.luau` from the modular source tree. This mirrors the
 * Wax 0.4.1 bundle format that the previous `version-1.luau` used:
 *   - an ObjectTree describing the virtual DOM (Folders + ModuleScripts)
 *   - ClosureBindings [refId] = closure per module
 *   - LineOffsets per ref for error line mapping
 *   - the standalone loader contract: return the MainModule API to loadstring
 *
 * The virtual DOM mirrors wax.project.json: an "Astra" folder whose MainModule
 * is `library_entrypoint.luau` and whose children are the source folders.
 *
 * Usage: node scripts/generate_bundle.js
 */

const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..");
const OUT = path.join(ROOT, "version-1.luau");

const CLASS_FOLDER = 1;
const CLASS_MODULE = 2;

// Tree layout: entrypoint + Types at root, everything else grouped in folders
// matching the modular architecture. Order matches wax.project.json style.
const TREE = [
  { file: "library_entrypoint.luau", name: "MainModule" },
  { file: "Types.luau", name: "Types" },
  { dir: "assets" }, // Folder, no closures
  { dir: "core" },
  { dir: "components" },
  { dir: "elements" },
  { dir: "settings" },
  { dir: "cache" },
  { dir: "functions" },
  { dir: "layouts" },
  { dir: "images" },
  { dir: "icons" },
  { dir: "themes" },
  { dir: "utilities" },
];

function readLuau(p) {
  return fs.readFileSync(p, "utf8").replace(/\r\n/g, "\n");
}

let nextRefId = 1;
const nodes = []; // flat list of { refId, name, className, isFolder }

function makeNode(name, className) {
  const refId = nextRefId++;
  nodes.push({ refId, name, className });
  return refId;
}

function hasLuau(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).some((d) => {
    if (d.isFile()) return d.name.endsWith(".luau");
    if (d.isDirectory() && !d.name.startsWith(".")) return hasLuau(path.join(dir, d.name));
    return false;
  });
}

// Build the tree bottom-up: returns wax ObjectTree object
function buildNode(entry) {
  if (entry.file) {
    const refId = makeNode(entry.name, CLASS_MODULE);
    return {
      refId,
      tree: [refId, CLASS_MODULE, [entry.name]],
      closure: readLuau(path.join(ROOT, entry.file)),
    };
  }
  if (entry.dir) {
    const dirPath = path.join(ROOT, entry.dir);
    // `entry.dir` is a path relative to ROOT and may be nested
    // ("components/window"), so the instance name is the last segment only.
    const dirName = entry.name || path.basename(entry.dir);
    const listing = fs.readdirSync(dirPath, { withFileTypes: true });

    const files = listing
      .filter((d) => d.isFile() && d.name.endsWith(".luau"))
      .map((d) => d.name)
      .sort();

    // Subfolders are recursed into, so the source tree can nest as deeply as
    // it likes ("components/window/input.luau"). Empty/non-Luau directories
    // are skipped rather than emitted as stray Folders.
    const subDirs = listing
      .filter((d) => d.isDirectory() && !d.name.startsWith("."))
      .map((d) => d.name)
      .sort()
      .filter((d) => hasLuau(path.join(dirPath, d)));

    // Folders without any Luau content (e.g. assets/) sync as plain Folders.
    if (files.length === 0 && subDirs.length === 0) {
      const folderRefId = makeNode(dirName, CLASS_FOLDER);
      return {
        refId: folderRefId,
        tree: [folderRefId, CLASS_FOLDER, [dirName], []],
        closures: [],
      };
    }

    const buildChildren = (names) => [
      ...names.map((f) =>
        buildNode({ file: path.join(entry.dir, f), name: f.replace(/\.luau$/, "") })
      ),
      ...subDirs.map((d) => buildNode({ dir: path.join(entry.dir, d), name: d })),
    ];

    // Rojo/Wax semantics: a folder containing init.luau syncs as a single
    // ModuleScript (the init file), with the sibling files as its children.
    // require(folder) returns the init module's value, so init files must use
    // `script.<sibling>` requires. The init file itself does NOT become a
    // child named "init" — Rojo merges it into the folder's ModuleScript.
    // Folders without init.luau stay Folders.
    if (files.indexOf("init.luau") !== -1) {
      // Build only real children — init.luau is merged into the folder node.
      const children = buildChildren(files.filter((f) => f !== "init.luau"));
      const refId = makeNode(dirName, CLASS_MODULE);
      return {
        refId,
        tree: [refId, CLASS_MODULE, [dirName], children.map((c) => c.tree)],
        closure: readLuau(path.join(ROOT, entry.dir, "init.luau")),
        closures: children.flatMap((c) => [c, ...(c.closures || [])]).filter(Boolean),
      };
    }

    // Plain folder (no init.luau): children sync as its child instances.
    const children = buildChildren(files);
    const refId = makeNode(dirName, CLASS_FOLDER);
    return {
      refId,
      tree: [refId, CLASS_FOLDER, [dirName], children.map((c) => c.tree)],
      closures: children.flatMap((c) => [c, ...(c.closures || [])]).filter(Boolean),
    };
  }
  throw new Error("Unknown tree entry: " + JSON.stringify(entry));
}

// The root "Astra" folder wraps everything.
const rootRefId = makeNode("Astra", CLASS_FOLDER);
const children = TREE.map(buildNode);
const allModules = children.flatMap((c) => [c, ...(c.closures || [])]).filter((c) => c.closure);

// ObjectTree must be an ARRAY OF ROOT OBJECTS (the wax runtime iterates it
// with `for _, Object in next, ObjectTree` and calls CreateRefFromObject on
// each entry). Wrapping the root object is load-bearing: emitting the root
// object directly makes the runtime index the raw refId number.
const objectTree = [
  [rootRefId, CLASS_FOLDER, ["Astra"], children.map((c) => c.tree)],
];

// --- Emit Lua ---

const lines = [];
lines.push("-- [[++++++++ WAX BUNDLED DATA BELOW ++++++++]]");
lines.push("");
lines.push("-- [[Generated by scripts/generate_bundle.js from the modular source tree.]]");
lines.push("-- [[Do not edit by hand; source files remain the source of truth.]]");
lines.push("");
lines.push("-- [[Will be used later for getting flattened globals]]");
lines.push("local ImportGlobals");
lines.push("");
lines.push("-- [[Holds direct closure data (defining this before the DOM tree for line debugging etc)]]");
lines.push("local ClosureBindings = {");
for (const mod of allModules) {
  const wrapped = mod.closure.replace(/\n/g, "\n");
  lines.push(`    [${mod.refId}] = function()local wax,script,require=ImportGlobals(${mod.refId})local ImportGlobals return (function(...)`);
  lines.push(wrapped);
  lines.push("end)() end,");
}
lines.push("}");
lines.push("");

// LineOffsets: physical line of each closure start inside this file
// computed after we know where each closure began. We recompute by tracking.
// (Built during a second pass below.)

const closureChunk = lines.join("\n");

// We need line numbers of each closure body's first line. Re-emit with tracking.
const out1 = lines.length; // informational only

// Compose final file in order: header, ObjectTree, ClosureBindings, LineOffsets, runtime.
// The previous bundle put ClosureBindings first, then the DOM tree, then
// LineOffsets, then the runtime. Keep that order.

const runtime = `

local task_defer = task and task.defer

    -- [[If we're not running on the Roblox engine, we won't have a \`task\` global]]
local Defer = task_defer or function(f, ...)
    coroutine_wrap(f)(...)
end

    -- [[ClassName "IDs"]]
local ClassNameIdBindings = {
    [1] = "Folder",
    [2] = "ModuleScript",
    [3] = "Script",
    [4] = "LocalScript",
    [5] = "StringValue",
}

local RefBindings = {} -- [[ [RefId] = RealObject ]]

local ScriptClosures = {}
local ScriptClosureRefIds = {} -- [[ [ScriptClosure] = RefId ]]
local StoredModuleValues = {}
local ScriptsToRun = {}

    -- [[wax.shared __index/__newindex]]
local SharedEnvironment = {}

    -- [[We're creating 'fake' instance refs soley for traversal of the DOM for require() compatibility]]

local RefChildren = {}

local unpack = table and table.unpack or unpack
local table_insert = table.insert
local table_remove = table.remove
local string_match = string.match
local next = next
local type = type
local tostring = tostring
local tonumber = tonumber
local error = error
local pcall = pcall
local setmetatable = setmetatable

local InstanceMethods = {
    GetFullName = { {}, function(self)
        local Path = self.Name
        local ObjectPointer = self.Parent

        while ObjectPointer do
            Path = ObjectPointer.Name .. "." .. Path

            ObjectPointer = ObjectPointer.Parent
        end

        return Path
    end},

    GetChildren = { {}, function(self)
        local ReturnArray = {}

        for Child in next, RefChildren[self] do
            table_insert(ReturnArray, Child)
        end

        return ReturnArray
    end},

    GetDescendants = { {}, function(self)
        local ReturnArray = {}

        for Child in next, RefChildren[self] do
            table_insert(ReturnArray, Child)

            for _, Descendant in next, Child:GetDescendants() do
                table_insert(ReturnArray, Descendant)
            end
        end

        return ReturnArray
    end},

    FindFirstChild = { {"string", "boolean?"}, function(self, name, recursive)
        local Children = RefChildren[self]

        for Child in next, Children do
            if Child.Name == name then
                return Child
            end
        end

        if recursive then
            for Child in next, Children do
                return Child:FindFirstChild(name, true)
            end
        end
    end},

    FindFirstAncestor = { {"string"}, function(self, name)
        local RefPointer = self.Parent
        while RefPointer do
            if RefPointer.Name == name then
                return RefPointer
            end
            RefPointer = RefPointer.Parent
        end
    end},

    WaitForChild = { {"string", "number?"}, function(self, name)
        return self:FindFirstChild(name)
    end},
}

local InstanceMethodProxies = {}
for MethodName, MethodObject in next, InstanceMethods do
    local Types = MethodObject[1]
    local Method = MethodObject[2]

    local EvaluatedTypeInfo = {}
    for ArgIndex, TypeInfo in next, Types do
        local ExpectedType, IsOptional = string_match(TypeInfo, "^([^%?]+)(%??)")
        EvaluatedTypeInfo[ArgIndex] = {ExpectedType, IsOptional}
    end

    InstanceMethodProxies[MethodName] = function(self, ...)
        if not RefChildren[self] then
            error("Expected ':' not '.' calling member function " .. MethodName, 2)
        end

        local Args = {...}
        for ArgIndex, TypeInfo in next, EvaluatedTypeInfo do
            local RealArg = Args[ArgIndex]
            local RealArgType = type(RealArg)
            local ExpectedType, IsOptional = TypeInfo[1], TypeInfo[2]

            if RealArg == nil and not IsOptional then
                error("Argument " .. RealArg .. " missing or nil", 3)
            end

            if ExpectedType ~= "any" and RealArgType ~= ExpectedType and not (RealArgType == "nil" and IsOptional) then
                error("Argument " .. ArgIndex .. " expects type \\"" .. ExpectedType .. "\\", got \\"" .. RealArgType .. "\\"", 2)
            end
        end

        return Method(self, ...)
    end
end

local function CreateRef(className, name, parent)
    local StringValue_Value

    local Children = setmetatable({}, {__mode = "k"})

    local function InvalidMember(member)
        error(member .. " is not a valid (virtual) member of " .. className .. " \\"" .. name .. "\\"", 3)
    end
    local function ReadOnlyProperty(property)
        error("Unable to assign (virtual) property " .. property .. ". Property is read only", 3)
    end

    local Ref = {}
    local RefMetatable = {}

    RefMetatable.__metatable = false

    RefMetatable.__index = function(_, index)
        if index == "ClassName" then
            return className
        elseif index == "Name" then
            return name
        elseif index == "Parent" then
            return parent
        elseif className == "StringValue" and index == "Value" then
            return StringValue_Value
        else
            local InstanceMethod = InstanceMethodProxies[index]

            if InstanceMethod then
                return InstanceMethod
            end
        end

        for Child in next, Children do
            if Child.Name == index then
                return Child
            end
        end

        InvalidMember(index)
    end

    RefMetatable.__newindex = function(_, index, value)
        if index == "ClassName" then
            ReadOnlyProperty(index)
        elseif index == "Name" then
            name = value
        elseif index == "Parent" then
            if value == Ref then
                return
            end

            if parent ~= nil then
                RefChildren[parent][Ref] = nil
            end

            parent = value

            if value ~= nil then
                RefChildren[value][Ref] = true
            end
        elseif className == "StringValue" and index == "Value" then
            StringValue_Value = value
        else
            InvalidMember(index)
        end
    end

    RefMetatable.__tostring = function()
        return name
    end

    setmetatable(Ref, RefMetatable)

    RefChildren[Ref] = Children

    if parent ~= nil then
        RefChildren[parent][Ref] = true
    end

    return Ref
end

local function CreateRefFromObject(object, parent)
    local RefId = object[1]
    local ClassNameId = object[2]
    local Properties = object[3]
    local Children = object[4]

    local ClassName = ClassNameIdBindings[ClassNameId]

    local Name = Properties and table_remove(Properties, 1) or ClassName

    local Ref = CreateRef(ClassName, Name, parent)
    RefBindings[RefId] = Ref

    if Properties then
        for PropertyName, PropertyValue in next, Properties do
            Ref[PropertyName] = PropertyValue
        end
    end

    if Children then
        for _, ChildObject in next, Children do
            CreateRefFromObject(ChildObject, Ref)
        end
    end

    return Ref
end

local RealObjectRoot = CreateRef("Folder", "[" .. EnvName .. "]")
for _, Object in next, ObjectTree do
    CreateRefFromObject(Object, RealObjectRoot)
end

for RefId, Closure in next, ClosureBindings do
    local Ref = RefBindings[RefId]

    ScriptClosures[Ref] = Closure
    ScriptClosureRefIds[Ref] = RefId

    local ClassName = Ref.ClassName
    if ClassName == "LocalScript" or ClassName == "Script" then
        table_insert(ScriptsToRun, Ref)
    end
end

local function LoadScript(scriptRef)
    local ScriptClassName = scriptRef.ClassName

    local StoredModuleValue = StoredModuleValues[scriptRef]
    if StoredModuleValue and ScriptClassName == "ModuleScript" then
        return unpack(StoredModuleValue)
    end

    local Closure = ScriptClosures[scriptRef]

    local function FormatError(originalErrorMessage)
        originalErrorMessage = tostring(originalErrorMessage)

        local VirtualFullName = scriptRef:GetFullName()

        local OriginalErrorLine, BaseErrorMessage = string_match(originalErrorMessage, "[^:]+:(%d+): (.+)")

        if not OriginalErrorLine or not LineOffsets then
            return VirtualFullName .. ":*: " .. (BaseErrorMessage or originalErrorMessage)
        end

        OriginalErrorLine = tonumber(OriginalErrorLine)
        local RefId = ScriptClosureRefIds[scriptRef]
        local LineOffset = LineOffsets[RefId]

        local RealErrorLine = OriginalErrorLine - LineOffset + 1
        if RealErrorLine < 0 then
            RealErrorLine = "?"
        end

        return VirtualFullName .. ":" .. RealErrorLine .. ": " .. BaseErrorMessage
    end

    if ScriptClassName == "LocalScript" or ScriptClassName == "Script" then
        local RunSuccess, ErrorMessage = pcall(Closure)
        if not RunSuccess then
            error(FormatError(ErrorMessage), 0)
        end
    else
        local PCallReturn = {pcall(Closure)}

        local RunSuccess = table_remove(PCallReturn, 1)
        if not RunSuccess then
            local ErrorMessage = table_remove(PCallReturn, 1)
            error(FormatError(ErrorMessage), 0)
        end

        StoredModuleValues[scriptRef] = PCallReturn
        return unpack(PCallReturn)
    end
end

function ImportGlobals(refId)
    local ScriptRef = RefBindings[refId]

    local function RealCall(f, ...)
        local PCallReturn = {pcall(f, ...)}

        local CallSuccess = table_remove(PCallReturn, 1)
        if not CallSuccess then
            error(PCallReturn[1], 3)
        end

        return unpack(PCallReturn)
    end

    local WaxShared = table.freeze and table.freeze(setmetatable({}, {
        __index = SharedEnvironment,
        __newindex = function(_, index, value)
            SharedEnvironment[index] = value
        end,
        __len = function()
            return #SharedEnvironment
        end,
        __iter = function()
            return next, SharedEnvironment
        end,
    })) or setmetatable({}, {
        __index = SharedEnvironment,
        __newindex = function(_, index, value)
            SharedEnvironment[index] = value
        end,
    })

    local function VirtualRequire(module)
        if module == wax then
            return WaxShared
        end

        local moduleRef = module

        if typeof and typeof(module) == "Instance" then
            moduleRef = module
        end

        if type(moduleRef) ~= "table" then
            error("Attempt to require an invalid module", 2)
        end

        local PathMatch = nil
        for RefId = 1, #RefBindings do
            if RefBindings[RefId] == moduleRef then
                PathMatch = RefId
                break
            end
        end

        if not PathMatch then
            error("Could not resolve require", 2)
        end

        local CurrentRefPointer = moduleRef

        -- [[Error text for the two guard branches below. Declared here rather
        -- [[than injected at generation time: the generator used to
        -- [[string-replace a "local ErrorNonModuleScript" declaration that the
        -- [[template never contained, so both names resolved to nil and the
        -- [[branches raised a blank message.]]
        local ErrorNonModuleScript = "Expected ModuleScript got " .. CurrentRefPointer.ClassName
        local ErrorSelfRequire = "Cannot require self"

        if CurrentRefPointer.ClassName ~= "ModuleScript" then
            error(ErrorNonModuleScript, 2)
        elseif CurrentRefPointer == ScriptRef then
            error(ErrorSelfRequire, 2)
        end

        return LoadScript(CurrentRefPointer)
    end

    return WaxShared, ScriptRef, VirtualRequire
end

for _, ScriptRef in next, ScriptsToRun do
    Defer(LoadScript, ScriptRef)
end

-- [[Standalone loader contract: return the public MainModule API to loadstring callers.]]
local AstraRoot = RealObjectRoot:FindFirstChild("Astra")
local MainModule = if AstraRoot then AstraRoot:FindFirstChild("MainModule") else nil
if MainModule then
    return LoadScript(MainModule)
end
error("Astra bundle is missing its MainModule", 0)
`;

// Serialize the ObjectTree in Lua syntax.
function luaValue(v, indent) {
  const pad = "    ".repeat(indent);
  const padIn = "    ".repeat(indent + 1);
  if (typeof v === "number") return String(v);
  if (typeof v === "string") return JSON.stringify(v);
  if (Array.isArray(v)) {
    if (v.length === 0) return "{}";
    const items = v.map((item) => padIn + luaValue(item, indent + 1) + ",");
    return "{\n" + items.join("\n") + "\n" + pad + "}";
  }
  throw new Error("Cannot serialize: " + typeof v);
}

// The tree entries store properties as arrays: {refId, classId, {[name]}, [children]}
// Names must survive as arrays of one string; children arrays may be empty.
// The original wax format used sparse-ish arrays; we emit plain arrays which is
// compatible with `next` iteration.

const treeLua = "local ObjectTree = " + luaValue(objectTree, 0) + "\n";

// Assemble final document and compute LineOffsets by scanning.
const finalParts = [];
finalParts.push(lines.join("\n")); // header + ClosureBindings (closure bodies included)
finalParts.push("\nlocal LineOffsets = {\n");
// We must compute offsets after knowing the layout; emit placeholder then fix.
const before = finalParts.join("\n");

// Compose with real offsets: build the full text first with a placeholder,
// then locate each closure's first body line.
let fullText =
  lines.join("\n") +
  "\n\nlocal LineOffsets = {\n__LINEOFFSETS__\n}\n\n" +
  "-- [[Misc AOT variable imports]]\nlocal WaxVersion = \"0.4.1\"\nlocal EnvName = \"WaxRuntime\"\n" +
  "\n" + treeLua +
  runtime;

// Compute offsets: for each module refId, find the line index where its body
// begins (the line after the wrapper line).
const textLines = fullText.split("\n");
const offsets = {};
for (const mod of allModules) {
  const marker = `local ImportGlobals return (function(...)`;
  // Find the wrapper line for this refId
  const wrapper = `    [${mod.refId}] = function()local wax,script,require=ImportGlobals(${mod.refId})local ImportGlobals return (function(...)`;
  const idx = textLines.indexOf(wrapper);
  if (idx === -1) {
    throw new Error("Closure wrapper not found for ref " + mod.refId);
  }
  // Body starts on the next line; Lua line numbers are 1-based.
  offsets[mod.refId] = idx + 2;
}

const offsetLua = Object.keys(offsets)
  .map((k) => `    [${k}] = ${offsets[k]},`)
  .join("\n");

fullText = fullText.replace("__LINEOFFSETS__", offsetLua);

// Sanity checks before writing
const expectedModules = allModules.length;
if (expectedModules < 60) {
  throw new Error("Refusing to write bundle: only " + expectedModules + " modules found (expected ~70)");
}

fs.writeFileSync(OUT, fullText);
console.log(
  `Wrote ${OUT}: ${expectedModules} modules, ${fullText.split("\n").length} lines, ${Buffer.byteLength(fullText)} bytes`
);
