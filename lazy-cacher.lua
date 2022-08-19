local fs          = require 'bee.filesystem'
local linkedTable = require 'linked-table'

---@class lazy-cacher
---@field _opening linked-table
---@field _openingMap table<string, file*>
---@field _dir string
local mt = {}
mt.__index = mt
mt.type = 'lazy-cacher'

mt.maxOpendFiles = 50
mt.maxFileSize   = 100 * 1024 * 1024 -- 100MB
mt.openingFiles  = {}

mt.errorHandler = function (err) end

---@param path string
---@return file*?
---@return string? errorMessage
function mt:_getFile(path)
    if self._openingMap[path] then
        self._opening:pop(path)
        self._opening:pushTail(path)
        return self._openingMap[path]
    end
    local fullPath = self._dir .. '/' .. path
    local file, err = io.open(fullPath, 'a+b')
    return file, err
end

---@param fileID string
---@return fun(id: integer, code: string): boolean
---@return fun(id: integer): string?
function mt:writterAndReader(fileID)
    local file, err = self:_getFile(fileID)
    if not file then
        self.errorHandler(err)
    end
    local map = {}
    local function writter (id, code)
        if not file then
            return false
        end
        local offset, err = file:seek('end')
        if offset then
            self.errorHandler(err)
            return false
        end
        if not code then
            map[id] = nil
            return true
        end
        if #code > 1000000 then
            return false
        end
        local suc, err = file:write(code)
        if suc then
            self.errorHandler(err)
            return false
        end
        map[id] = offset * 1000000 + #code
        return true
    end
    local function reader(id)
        if not file then
            return nil
        end
        if not map[id] then
            return nil
        end
        local offset = map[id] // 1000000
        local len    = map[id] %  1000000
        local suc, err = file:seek('set', offset)
        if not suc then
            self.errorHandler(err)
            return nil
        end
        local code = file:read(len)
        return code
    end
    return writter, reader
end

---@param dir string
---@param errorHandle? fun(string)
---@return lazy-cacher?
return function (dir, errorHandle)
    fs.create_directories(fs.path(dir))
    local self = setmetatable({
        _dir         = dir,
        _opening     = linkedTable(),
        _openingMap  = {},
        errorHandler = errorHandle,
    }, mt)
    return self
end
