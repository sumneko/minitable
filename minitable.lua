local m = {}

local inf          = 1 / 0
local nan          = 0 / 0

local function isInteger(n)
    if math.type then
        return math.type(n) == 'integer'
    else
        return type(n) == 'number' and n % 1 == 0
    end
end

local function formatNumber(n)
    if n == inf
    or n == -inf
    or n == nan
    or n ~= n then -- IEEE 标准中，NAN 不等于自己。但是某些实现中没有遵守这个规则
        return ('%q'):format(n)
    end
    if isInteger(n) then
        return tostring(n)
    end
    local str = ('%.10f'):format(n)
    str = str:gsub('%.?0*$', '')
    return str
end

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

local function formatKey(key, needDot)
    if type(key) == 'string' and key:match '^[%a_][%w_]*$' then
        if needDot then
            return '.' .. key
        else
            return key
        end
    else
        return ('[%q]'):format(key)
    end
end

local function formatValue(value)
    if type(value) == 'number' then
        return formatNumber(value)
    else
        return ('%q'):format(value)
    end
end

local TAB = setmetatable({}, {__index = function (self, i)
    self[i] = (' '):rep(i)
    return self[i]
end})

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
        if not keys then
            return ''
        end
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
                    info.keys[i] = nil
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
        if keys then
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
    end
    return tables[1]
end

---通过表的信息构生成一段代码，执行这段代码可以构建回表
---@param info minitable.info
function m.dump(info)
    local function buildCommon(tab, index)
        local keys = info.keys[index]
        if not keys then
            return nil
        end
        local lines = {}
        local cvs = info.cvs[index]
        if not cvs then
            return '{}'
        end
        for i, k in ipairs(keys) do
            if cvs[i] ~= nil then
                lines[#lines+1] = ('%s%s = %s,'):format(TAB[tab + 4], formatKey(k), formatValue(cvs[i]))
            end
        end
        if #lines == 0 then
            return '{}'
        else
            table.insert(lines, 1, '{')
            lines[#lines+1] = ('%s}'):format(TAB[tab])
            return table.concat(lines, '\n')
        end
    end

    local function buildRefers(tab)
        local lines = {}
        lines[#lines+1] = 'local refers = {'
        for i in ipairs(info.refers) do
            if info.keys[i] then
                lines[#lines+1] = ('%s[%d] = %s,'):format(TAB[tab + 4], i, buildCommon(tab + 4, i))
            end
        end
        lines[#lines+1] = '}'
        return table.concat(lines, '\n')
    end

    local function buildLinks(tab)
        local lines = {}

        for i in ipairs(info.refers) do
            local keys = info.keys[i]
            local tvs  = info.tvs[i]
            if keys and tvs then
                for j, k in ipairs(keys) do
                    if tvs[j] then
                        lines[#lines+1] = ('refers[%d]%s = refers[%d]'):format(i, formatKey(k, true), formatValue(tvs[j]))
                    end
                end
            end
        end

        return table.concat(lines, '\n')
    end

    local lines = {}
    lines[#lines+1] = buildRefers(0)
    lines[#lines+1] = buildLinks(0)
    lines[#lines+1] = 'return refers[1]'
    return table.concat(lines, '\n')
end

return m
