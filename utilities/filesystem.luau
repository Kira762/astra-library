local serviceProvider = require(script.Parent.services)
local filesystem = {}

local isStudio = serviceProvider.getService("RunService"):IsStudio()
local hasExecutorFilesystem = not isStudio
    and typeof(writefile) == "function"
    and typeof(readfile) == "function"
    and typeof(isfile) == "function"
    and typeof(isfolder) == "function"
    and typeof(makefolder) == "function"
    and typeof(listfiles) == "function"
    and typeof(delfile) == "function"
    and typeof(delfolder) == "function"

if hasExecutorFilesystem then
        function filesystem.writefile(writePath: string, writeContents: string)
        writefile(writePath, writeContents)
    end

    function filesystem.readfile(readPath: string): string
        return readfile(readPath)
    end

            if typeof(appendfile) == "function" then
        function filesystem.appendfile(appendPath: string, appendContents: string)
            appendfile(appendPath, appendContents)
        end
    end

    function filesystem.isfile(isFilePath: string): boolean
        return isfile(isFilePath)
    end

    function filesystem.delfile(deleteFilePath: string)
        delfile(deleteFilePath)
    end

    function filesystem.listfiles(listDir: string): { string }
        return listfiles(listDir)
    end

    function filesystem.makefolder(makeFolderPath: string)
        makefolder(makeFolderPath)
    end

    function filesystem.isfolder(isFolderPath: string): boolean
        return isfolder(isFolderPath)
    end

    function filesystem.delfolder(deleteFolderPath: string)
        delfolder(deleteFolderPath)
    end
elseif isStudio then
            local rootFolder = Instance.new("Folder")
    rootFolder.Name = "Filesystem"
    rootFolder.Parent = serviceProvider.getService("ReplicatedStorage")

    local function splitPath(splitInput: string): { string }
        local segments = {}
        for segment in string.gmatch(splitInput, "[^/]+") do
            table.insert(segments, segment)
        end
        return segments
    end

    local function resolveParent(parentSegments: { string }, createMissing: boolean): Instance?
        local current: Instance = rootFolder
        for i = 1, #parentSegments - 1 do
            local child = current:FindFirstChild(parentSegments[i])
            if not child then
                if not createMissing then
                    return nil
                end
                local newFolder = Instance.new("Folder")
                newFolder.Name = parentSegments[i]
                newFolder.Parent = current
                child = newFolder
            end
            current = child :: Instance
        end
        return current
    end

    local function asStringValue(candidate: Instance?): StringValue?
        if candidate and candidate:IsA("StringValue") then
            return candidate
        end
        return nil
    end

    function filesystem.writefile(studioWritePath: string, studioWriteContents: string)
        local writeSegments = splitPath(studioWritePath)
        assert(#writeSegments > 0, "Invalid path")

        local writeParent = resolveParent(writeSegments, true)
        assert(writeParent, "Invalid path")
        local writeName = writeSegments[#writeSegments]

        local existingWrite = writeParent:FindFirstChild(writeName)
        local existingValue = asStringValue(existingWrite)
        if existingValue then
            existingValue.Value = studioWriteContents
        else
            if existingWrite then
                existingWrite:Destroy()
            end
            local newValue = Instance.new("StringValue")
            newValue.Name = writeName
            newValue.Value = studioWriteContents
            newValue.Parent = writeParent
        end
    end

    function filesystem.readfile(studioReadPath: string): string
        local readSegments = splitPath(studioReadPath)
        assert(#readSegments > 0, "Invalid path")

        local readParent = resolveParent(readSegments, false)
        assert(readParent, "File not found: " .. studioReadPath)

        local readChild = readParent:FindFirstChild(readSegments[#readSegments])
        local readValue = asStringValue(readChild)
        assert(readValue, "File not found: " .. studioReadPath)

        return readValue.Value
    end

    function filesystem.isfile(studioIsFilePath: string): boolean
        local isFileSegments = splitPath(studioIsFilePath)
        if #isFileSegments == 0 then
            return false
        end

        local isFileParent = resolveParent(isFileSegments, false)
        if not isFileParent then
            return false
        end

        return asStringValue(isFileParent:FindFirstChild(isFileSegments[#isFileSegments])) ~= nil
    end

    function filesystem.listfiles(studioListDir: string): { string }
        local listSegments = splitPath(studioListDir)
        local listFolder: Instance = rootFolder

        for _, listSegment in listSegments do
            local listChild = listFolder:FindFirstChild(listSegment)
            if not listChild or not listChild:IsA("Folder") then
                error("Folder not found: " .. studioListDir)
            end
            listFolder = listChild
        end

        local listed: { string } = {}
        for _, listEntry in listFolder:GetChildren() do
            table.insert(listed, studioListDir .. "/" .. listEntry.Name)
        end
        return listed
    end

    function filesystem.delfile(studioDeleteFilePath: string)
        local deleteFileSegments = splitPath(studioDeleteFilePath)
        assert(#deleteFileSegments > 0, "Invalid path")

        local deleteFileParent = resolveParent(deleteFileSegments, false)
        assert(deleteFileParent, "File not found: " .. studioDeleteFilePath)

        local deleteFileChild = deleteFileParent:FindFirstChild(deleteFileSegments[#deleteFileSegments])
        local deleteFileValue = asStringValue(deleteFileChild)
        assert(deleteFileValue, "File not found: " .. studioDeleteFilePath)

        deleteFileValue:Destroy()
    end

    function filesystem.makefolder(studioMakeFolderPath: string)
        local makeFolderSegments = splitPath(studioMakeFolderPath)
        if #makeFolderSegments == 0 then
            return
        end

        local makeFolderCurrent: Instance = rootFolder
        for _, makeFolderSegment in makeFolderSegments do
            local makeFolderChild = makeFolderCurrent:FindFirstChild(makeFolderSegment)
            if not makeFolderChild then
                local makeFolderNew = Instance.new("Folder")
                makeFolderNew.Name = makeFolderSegment
                makeFolderNew.Parent = makeFolderCurrent
                makeFolderChild = makeFolderNew
            end
            makeFolderCurrent = makeFolderChild :: Instance
        end
    end

    function filesystem.isfolder(studioIsFolderPath: string): boolean
        local isFolderSegments = splitPath(studioIsFolderPath)
        if #isFolderSegments == 0 then
            return false
        end

        local isFolderCurrent: Instance = rootFolder
        for _, isFolderSegment in isFolderSegments do
            local isFolderChild = isFolderCurrent:FindFirstChild(isFolderSegment)
            if not isFolderChild or not isFolderChild:IsA("Folder") then
                return false
            end
            isFolderCurrent = isFolderChild
        end
        return true
    end

    function filesystem.delfolder(studioDeleteFolderPath: string)
        local deleteFolderSegments = splitPath(studioDeleteFolderPath)
        assert(#deleteFolderSegments > 0, "Invalid path")

        local deleteFolderParent = resolveParent(deleteFolderSegments, false)
        assert(deleteFolderParent, "Folder not found: " .. studioDeleteFolderPath)

        local deleteFolderChild = deleteFolderParent:FindFirstChild(deleteFolderSegments[#deleteFolderSegments])
        assert(deleteFolderChild and deleteFolderChild:IsA("Folder"), "Folder not found: " .. studioDeleteFolderPath)

        deleteFolderChild:Destroy()
    end
end

if filesystem.writefile and not filesystem.appendfile then
    function filesystem.appendfile(fallbackAppendPath: string, fallbackAppendContents: string)
        local fallbackExisting = if filesystem.isfile(fallbackAppendPath) then filesystem.readfile(fallbackAppendPath) else nil
        filesystem.writefile(fallbackAppendPath, if fallbackExisting then fallbackExisting .. fallbackAppendContents else fallbackAppendContents)
    end
end

function filesystem.ensureFolder(ensureFolderPath: string)
    if not filesystem.isfolder(ensureFolderPath) then
        filesystem.makefolder(ensureFolderPath)
    end
end

function filesystem.ensureDir(ensureDirPath: string)
    local partial = ""
    for ensureSegment in string.gmatch(ensureDirPath, "[^/]+") do
        partial = if partial == "" then ensureSegment else partial .. "/" .. ensureSegment
        if not filesystem.isfolder(partial) then
            filesystem.makefolder(partial)
        end
    end
end

return filesystem
