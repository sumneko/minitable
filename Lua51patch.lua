local ipairs       = ipairs
local getmetatable = getmetatable
local type         = type

local m = {}

---
---@param t table
---@return function
function m.ipairs(t)
    local mt = getmetatable(t)
    if mt and mt.__ipairs then
        return mt.__ipairs(t)
    else
        return ipairs(t)
    end
end

---
---@param t table
---@return integer
function m.len(t)
    if type(t) == 'table' then
        local mt = getmetatable(t)
        if mt and mt.__len then
            return mt.__len(t)
        end
    end
    return #t
end

return m
