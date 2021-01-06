local m = {}

local function makeMiniInfo(t)
    local info = {
        common = {},
        childs = {},
        refers = {},
    }
    local mark = {}
    local queue = {t}
    local index = 1
    info.refers[index] = t
    mark[t] = index
    while #queue > 0 do
        local v = queue[#queue]
        queue[#queue] = nil
        for k, cv in pairs(v) do
            if type(cv) == 'table' then
                if not info.childs[index] then
                    info.childs[index] = {}
                end
                if mark[cv] then
                    info.childs[index][k] = mark[t]
                else
                    queue[#queue+1] = cv
                    local childs = info.childs[index]
                    index = index + 1
                    mark[cv] = index
                    info.refers[index] = cv
                    childs[k] = index
                end
            else
                if not info.common[index] then
                    info.common[index] = {}
                end
                info.common[index][k] = cv
            end
        end
    end
    return info
end

local function miniBySameTable()

end

function m.mini(t, level)
    local info = makeMiniInfo(t)
    if level >= 1 then
    end
    return info
end

return m
