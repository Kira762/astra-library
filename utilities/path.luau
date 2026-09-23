local path = {}

function path.join(base: string, suffix: string?): string
    if not suffix or suffix == "" then
        return base
    end

    return base .. "/" .. suffix
end

local function stripDotDot(input: string): string
    local previous
    repeat
        previous = input
        input = input:gsub("%.%.", "")
    until input == previous
    return input
end

function path.sanitizeFolder(folderValue: unknown): string
    local cleanedFolder = tostring(folderValue):gsub("\\", "/"):gsub('[:<>"|?*%c]', "")
    cleanedFolder = stripDotDot(cleanedFolder):gsub("/+", "/")
    return (cleanedFolder:gsub("^/+", ""))
end

function path.sanitizeFile(fileValue: unknown): string
    local cleanedFile = tostring(fileValue):gsub("[/\\]", ""):gsub('[:<>"|?*%c]', "")
    return stripDotDot(cleanedFile)
end

function path.basename(pathValue: unknown): string
    return tostring(pathValue):match("[^/\\]+$") or tostring(pathValue)
end

function path.stripExtension(nameValue: unknown, extension: string?): string
    local nameText = tostring(nameValue)
    if extension and extension ~= "" then
        if nameText:sub(-#extension):lower() == extension:lower() then
            return nameText:sub(1, -#extension - 1)
        end
        return nameText
    end

    local matchedName = nameText:match("^(.+)%.%w+$")
    return matchedName or nameText
end

return path
