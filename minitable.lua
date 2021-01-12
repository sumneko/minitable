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
        protos = {},
    }
    local queue  = {t}
    local index  = 0

    local function makeValues(ot)
        index = index + 1
        local values = {}
        info.refmap[ot] = index
        info.values[index] = values
        info.refmap[values] = index
    end

    makeValues(t)

    while #queue > 0 do
        local current = queue[#queue]
        queue[#queue] = nil

        -- 把对象的所有 key 都找出，并按照固定顺序来保存
        local myIndex = info.refmap[current]
        local keys    = {}
        local values  = info.values[myIndex]
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
                if not info.refmap[v] then
                    makeValues(v)
                    queue[#queue+1] = v
                end
                values[k] = info.values[info.refmap[v]]
            else
                values[k] = v
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
        for i = 1, #info.values do
            local token = makeToken(i)
            if token ~= '' then
                if tokens[token] then
                    links[i] = tokens[token]
                    info.keys[i] = nil
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
                    values[k] = info.values[links[ref]]
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
        if not keys or #keys <= 3 then
            return nil
        end
        return table.concat(keys)
    end

    ---从投票中获取票数最高的值，使用稳定的冒泡
    ---@param votes table
    local function getBestValueByVotes(votes)
        local keys = {}
        for k in pairs(votes) do
            keys[#keys+1] = k
        end
        table.sort(keys, function (a, b)
            return tostring(a) < tostring(b)
        end)
        local ck
        local cv = 0
        for _, k in ipairs(keys) do
            if votes[k] > cv then
                cv = votes[k]
                ck = k
            end
        end
        return ck
    end

    local function makeGoodTemplate(protos)
        local template = {}
        local keys   = info.keys[protos[1]]
        for _, k in ipairs(keys) do
            -- 找一个最好的值
            local votes = {}
            for _, ci in ipairs(protos) do
                local values = info.values[ci]
                local v = values[k]
                if v == nil
                or v == nan
                or v ~= v then
                else
                    votes[v] = (votes[v] or 0) + 1
                end
            end
            local bestValue = getBestValueByVotes(votes)
            template[k] = bestValue
        end
        return keys, template
    end

    -- 找出使用同一个meta的对象
    local metas = {}
    for i = 1, #info.values do
        local meta = makeMeta(i)
        if meta then
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
            local keys, tvalues = makeGoodTemplate(protos)

            protos.template = tvalues

            for _, ci in ipairs(protos) do
                local cvalues = info.values[ci]
                if cvalues ~= protos.template then
                    for i, k in ipairs(keys) do
                        if tvalues[k] == cvalues[k] then
                            cvalues[k] = nil
                        end
                    end
                end
            end
        end
    end
end

---尝试压缩一张表（内存方面）
---@param t     table
---@param level integer | '0' | '1' | '2' --压缩等级
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
function m.rawbuild(info)
    for _, proto in ipairs(info.protos) do
        local template = proto.template
        if template then
            local len = #template
            local mt = {
                __index  = template,
                __len    = function ()
                    return len
                end,
                __pairs  = function (self)
                    return function (t, k)
                        local nk = next(template, k)
                        return nk, t[nk]
                    end, self, nil
                end,
            }
            for _, ci in ipairs(proto) do
                local values = info.values[ci]
                if template ~= values then
                    setmetatable(values, mt)
                end
            end
        end
    end
    return info.values[1]
end

---通过表的信息构生成一段代码，执行这段代码可以构建回表
---@param info minitable.info
---@return string
function m.dump(info)
    local function buildCommon(tab, index)
        local keys = info.keys[index]
        if not keys then
            return nil
        end
        local lines = {}
        local values = info.values[index]
        for _, k in ipairs(keys) do
            local v = values[k]
            if v ~= nil and not info.refmap[v] then
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
        for i in ipairs(info.values) do
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
        for i in ipairs(info.values) do
            local keys   = info.keys[i]
            local values = info.values[i]
            if keys then
                local hasCurrent
                for _, k in ipairs(keys) do
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

    local function buildTemplate(tab, proto)
        local keys = info.keys[proto[1]]
        if not keys then
            return nil
        end
        local template = proto.template
        local lines = {}
        for _, k in ipairs(keys) do
            local v = template[k]
            if info.refmap[v] then
                lines[#lines+1] = ('%s%s = refers[%d],'):format(TAB[tab + 4], formatKey(k), info.refmap[v])
            else
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

    local function buildProtos(tab)
        if #info.protos == 0 then
            return nil
        end
        local lines = {}

        lines[#lines+1] = 'local protos = {'

        for i, proto in ipairs(info.protos) do
            if proto.template and info.values[proto] ~= proto.template then
                lines[#lines+1] = ('%s[%s] = %s,'):format(TAB[tab + 4], i, buildTemplate(tab + 4, proto))
            end
        end

        lines[#lines+1] = '}'

        return table.concat(lines, '\n')
    end

    local function buildMetaTable(tab)
        local lines = {}

        lines[#lines+1] = 'local setmetatable = setmetatable'
        lines[#lines+1] = 'local next = next'
        lines[#lines+1] = 'local mt'
        for i, proto in ipairs(info.protos) do
            if proto.template then
                lines[#lines+1] = ([[
mt = {
    __index = protos[%d],
    __len   = function ()
        return %d
    end,
    __pairs = function (self)
        return function (t, k)
            local nk = next(protos[%d], k)
            return nk, t[nk]
        end, self, nil
    end,
}]]):format(i, #proto.template, i)
                for _, ci in ipairs(proto) do
                    if proto.template ~= info.values[ci] then
                        lines[#lines+1] = ('setmetatable(refers[%d], mt)'):format(ci)
                    end
                end
            end
        end

        return table.concat(lines, '\n')
    end

    local lines = {}
    lines[#lines+1] = 'local function buildTable()'
    lines[#lines+1] = buildRefers(0)
    lines[#lines+1] = buildLinks(0)
    lines[#lines+1] = buildProtos(0)
    lines[#lines+1] = buildMetaTable(0)
    lines[#lines+1] = 'return refers[1]'
    lines[#lines+1] = 'end'
    lines[#lines+1] = 'return buildTable()'
    lines[#lines+1] = ''
    return table.concat(lines, '\n')
end

---通过表的信息构建回表
---@param info minitable.info
---@return table
function m.build(info)
    local dump = m.dump(info)
    return assert((loadstring or load)(dump))()
end

return m
