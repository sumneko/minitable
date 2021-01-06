local m = {}

local function compareCheat()
    local oldMT = debug.getmetatable('')
    debug.setmetatable('', {
        __lt = function (a, b)
            local tpa = type(a)
            local tpb = type(b)
            if tpa == 'number' then
                return true
            end
            if tpb == 'number' then
                return false
            end
            return false
        end,
    })
    return setmetatable({}, { __close = function ()
        debug.setmetatable('', oldMT)
    end})
end

local function makeMiniInfo(t)
    local info = {
        keys   = {},
        cvs    = {},
        tvs    = {},
        refers = {},
    }
    local mark = {}
    local queue = {t}
    local index = 1
    info.refers[index] = t
    mark[t] = index
    while #queue > 0 do
        local current = queue[#queue]
        queue[#queue] = nil

        -- 把对象的所有 key 都找出，并按照固定顺序来保存
        local myIndex = mark[current]
        local keys = {}
        for k in pairs(current) do
            keys[#keys+1] = k
        end
        table.sort(keys)
        info.keys[myIndex] = keys

        -- 以key的顺序来遍历值
        for i = 1, #keys do
            local k = keys[i]
            local v = current[k]
            if type(v) == 'table' then
                if not info.tvs[myIndex] then
                    info.tvs[myIndex] = {}
                end
                if not mark[v] then
                    index = index + 1
                    mark[v] = index
                    queue[#queue+1] = v
                    info.refers[index] = v
                end
                info.tvs[myIndex][k] = mark[v]
            else
                if not info.cvs[myIndex] then
                    info.cvs[myIndex] = {}
                end
                info.cvs[myIndex][k] = v
            end
        end
    end

    return info
end

local function miniBySameTable()

end

function m.mini(t, level)
    local release <close> = compareCheat()
    local info = makeMiniInfo(t)
    if level >= 1 then
    end
    return info
end

return m
