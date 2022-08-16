local lazy = require 'lazytable'
local util = require 'utility'

local a1 = { x = 1, y = 2, z = 3 }
local a0 = lazy.build(a1)

assert(util.equal(a1, a0))

local b1 = { x = 1, y = 2, z = 3 }
local b2 = { a = '1', b = '2', c = '3' }
b1[1]  = b2
b1[2]  = b1
b1[3]  = 'xxx'
b2[10] = b1
local b0 = lazy.build(b1)
assert(util.equal(b1, b0))

local c1 = { ['if'] = 1 }
local c0 = lazy.build(c1)
assert(util.equal(c1, c0))

local d1 = {1, 2, 3, 4, 5, 6, 7, 8, 9}
local d0 = lazy.build(d1)
assert(#d1 == #d0)

collectgarbage 'stop'
local mem1 = collectgarbage 'count'
local e1 = {}
for i = 1, 1000 do
    local e2 = {}
    e1['xxx' .. i] = e2
    for j = 1, 1000 do
        e2['yyy' .. j] = 'zzz'
    end
end
collectgarbage()
collectgarbage()
local mem2 = collectgarbage 'count'
local e0 = lazy.build(e1)
collectgarbage()
collectgarbage()
local mem3 = collectgarbage 'count'
for i = 1, 1000 do
    e0['xxx' .. i]['x'] = true
end
local mem4 = collectgarbage 'count'

print(mem2 - mem1, mem3 - mem2, mem4 - mem3)

print('测试通过')
