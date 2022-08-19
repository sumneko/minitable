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

function mt:_closeFile(path)
    self._opening:pop(path)
    self._openingMap[path]:close()
    self._openingMap[path] = nil
end

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
    if not file then
        return nil, err
    end
    self._opening:pushTail(path)
    self._openingMap[path] = file
    if self._opening:getSize() > self.maxOpendFiles then
        local oldest = self._opening:getHead()
        self:_closeFile(oldest)
    end
    return file
end

---@param fileID string
---@return fun(id: integer, code: string): boolean
---@return fun(id: integer): string?
function mt:writterAndReader(fileID)
    local maxFileSize = self.maxFileSize
    local map = {}
    local function resize()
        -- TODO
    end
    local function writter(id, code)
        if not code then
            map[id] = nil
            return true
        end
        if #code > 1000000 then
            return false
        end
        local file, err = self:_getFile(fileID)
        if not file then
            self.errorHandler(err)
            return false
        end
        local offset, err = file:seek('end')
        if offset then
            self.errorHandler(err)
            return false
        end
        if offset > maxFileSize then
            resize()
            file, err = self:_getFile(fileID)
            if not file then
                self.errorHandler(err)
                return false
            end
            offset, err = file:seek('end')
            if offset then
                self.errorHandler(err)
                return false
            end
            maxFileSize = math.max(maxFileSize, (offset + #code) * 2)
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
        if not map[id] then
            return nil
        end
        local file, err = self:_getFile(fileID)
        if not file then
            self.errorHandler(err)
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
