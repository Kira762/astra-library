local fs = require(script.Parent.filesystem)

local persistenceWrite = {}

local tempSuffix = ".saving"

function persistenceWrite.tempPathFor(path: string): string
    return path .. tempSuffix
end

function persistenceWrite.write(folder: string, filePath: string, contents: string)
    local tempPath = persistenceWrite.tempPathFor(filePath)

    fs.ensureDir(folder)
    fs.writefile(tempPath, contents)

    if fs.readfile(tempPath) ~= contents then
        error("parked copy did not write cleanly")
    end

    fs.writefile(filePath, contents)
    pcall(fs.delfile, tempPath)
end

return persistenceWrite
