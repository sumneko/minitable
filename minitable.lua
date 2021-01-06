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

---创建表的信息
---@param t table
---@return minitable.info
local function makeMiniInfo(t)
    ---@class minitable.info
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
                info.tvs[myIndex][i] = mark[v]
            else
                if not info.cvs[myIndex] then
                    info.cvs[myIndex] = {}
                end
                info.cvs[myIndex][i] = v
            end
        end
    end

    return info
end

---把完全相同的表连接到同一个引用上
---@param info minitable.info
local function miniBySameTable(info)
    local tokenCache = {}
    local function makeToken(i)
        if tokenCache[i] then
            return tokenCache[i]
        end
        local keys = info.keys[i]
        local cvs  = info.cvs[i]
        local tvs  = info.tvs[i]
        local buf  = {}
        for x, k in ipairs(keys) do
            buf[#buf+1] = k
            if tvs and tvs[x] then
                buf[#buf+1] = tvs[x]
            elseif cvs then
                buf[#buf+1] = type(cvs[x])
                buf[#buf+1] = tostring(cvs[x])
            end
        end
        tokenCache[i] = table.concat(buf)
        return tokenCache[i]
    end

    -- 找出完全相同的对象
    for _ = 1, 1000 do
        local tokens = {}
        local links  = {}
        for i = 1, #info.refers do
            local token = makeToken(i)
            if token ~= '' then
                if tokens[token] then
                    links[i] = tokens[token]
                    info.keys[i] = {}
                    info.cvs[i]  = nil
                    info.tvs[i]  = nil
                    tokenCache[i] = ''
                else
                    tokens[token] = i
                end
            end
        end

        if not next(links) then
            break
        end

        --print('第', _, '次', next(links))

        -- 遍历tvs，把引用改过去
        for i, tvs in pairs(info.tvs) do
            for k, j in pairs(tvs) do
                if links[j] then
                    tvs[k] = links[j]
                    tokenCache[i] = nil
                end
            end
        end
    end
end

---尝试压缩一张表（内存方面）
---@param t     table
---@param level integer --压缩等级
---@return minitable.info
function m.mini(t, level)
    local release <close> = compareCheat()
    local info = makeMiniInfo(t)
    if level >= 1 then
        miniBySameTable(info)
    end
    return info
end

---通过表的信息构建回表
---@param info minitable.info
function m.build(info)
    local tables = {}
    for i = 1, #info.refers do
        tables[i] = {}
    end
    for i in ipairs(info.refers) do
        local t    = tables[i]
        local keys = info.keys[i]
        local cvs  = info.cvs[i]
        local tvs  = info.tvs[i]
        for x, k in ipairs(keys) do
            if tvs and tvs[x] then
                t[k] = tables[tvs[x]]
            elseif cvs then
                t[k] = cvs[x]
            end
        end
    end
    return tables[1]
end

return m
