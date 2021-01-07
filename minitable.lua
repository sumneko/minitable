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
        values = {},
        refmap = {},
        refers = {},
        protos = {},
    }
    local queue = {t}
    local index = 1
    info.refers[index] = t
    info.refmap[t] = index
    while #queue > 0 do
        local current = queue[#queue]
        queue[#queue] = nil

        -- 把对象的所有 key 都找出，并按照固定顺序来保存
        local myIndex = info.refmap[current]
        local keys   = {}
        local values = {}
        for k in pairs(current) do
            keys[#keys+1] = k
        end
        table.sort(keys)
        info.keys[myIndex] = keys
        info.values[myIndex] = values

        -- 以key的顺序来遍历值
        for i = 1, #keys do
            local k = keys[i]
            local v = current[k]
            values[k] = v
            if type(v) == 'table' then
                if not info.refmap[v] then
                    index = index + 1
                    info.refmap[v] = index
                    info.refers[index] = v
                    queue[#queue+1] = v
                end
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
        local values = info.values[i]
        local buf  = {}
        for x, k in ipairs(keys) do
            buf[#buf+1] = k
            local v = values[k]
            local ref = info.refmap[v]
            if ref then
                buf[#buf+1] = ref
            else
                buf[#buf+1] = type(v)
                buf[#buf+1] = tostring(v)
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
                    info.values[i]  = nil
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
        for i, values in pairs(info.values) do
            for k, v in pairs(values) do
                local ref = info.refmap[v]
                if links[ref] then
                    values[k] = info.refers[links[ref]]
                    tokenCache[i] = nil
                end
            end
        end
    end
end

---把相似的对象设置为共享同一个元表
---@param info minitable.info
local function miniBySameTemplate(info)
    local function makeMeta(i)
        local keys = info.keys[i]
        if not keys then
            return ''
        end
        return table.concat(keys)
    end

    local function makeBestTemplate(protos)
        local ti = protos[1]
        local keys   = info.keys[ti]
        local values = info.values[ti]
        return keys, values
    end

    -- 找出使用同一个meta的对象
    local metas = {}
    for i = 1, #info.refers do
        local meta = makeMeta(i)
        if meta ~= '' then
            if not metas[meta] then
                metas[meta] = {}
                info.protos[#info.protos+1] = metas[meta]
            end
            metas[meta][#metas[meta]+1] = i
        end
    end

    -- 清理差异数据
    for _, protos in ipairs(info.protos) do
        if #protos > 1 then
            -- TODO 目前先假定第一个对象是模板
            local keys, tvalues = makeBestTemplate(protos)

            protos.template = tvalues

            for _, ci in ipairs(protos) do
                local cvalues = info.values[ci]
                for i, k in ipairs(keys) do
                    if tvalues[k] == cvalues[k] then
                        cvalues[k] = nil
                    end
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
    local info = makeMiniInfo(t)
    if level >= 1 then
        miniBySameTable(info)
    end
    if level >= 2 then
        miniBySameTemplate(info)
    end
    return info
end

---通过表的信息构建回表
---@param info minitable.info
function m.build(info)
    return info.values[1]
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
        local values = info.values[index]
        for i, k in ipairs(keys) do
            local v = values[k]
            if not info.refmap[v] then
                lines[#lines+1] = ('%s%s = %s,'):format(TAB[tab + 4], formatKey(k), formatValue(v))
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
        lines[#lines+1] = 'local current'
        for i in ipairs(info.refers) do
            local keys   = info.keys[i]
            local values = info.values[i]
            if keys then
                local hasCurrent
                for j, k in ipairs(keys) do
                    local v = values[k]
                    if info.refmap[v] then
                        if not hasCurrent then
                            hasCurrent = true
                            lines[#lines+1] = ('current = refers[%d]'):format(i)
                        end
                        lines[#lines+1] = ('current%s = refers[%d]'):format(formatKey(k, true), formatValue(info.refmap[v]))
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
