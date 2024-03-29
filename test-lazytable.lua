local lazy  = require 'lazytable'
local util  = require 'utility'
local fs    = require 'bee.filesystem'
local cacher= require 'lazy-cacher'

local a1 = { x = 1, y = 2, z = 3 }
local a0 = lazy.build(a1):entry()

assert(util.equal(a1, a0))

local b1 = { x = 1, y = 2, z = 3 }
local b2 = { a = '1', b = '2', c = '3' }
b1[1]  = b2
b1[2]  = b1
b1[3]  = 'xxx'
b2[10] = b1
local b0 = lazy.build(b1):entry()
assert(util.equal(b1, b0))

local c1 = { ['if'] = 1 }
local c0 = lazy.build(c1):entry()
assert(util.equal(c1, c0))

local d1 = {1, 2, 3, 4, 5, 6, 7, 8, 9}
local d0 = lazy.build(d1):entry()
assert(#d1 == #d0)

collectgarbage 'stop'
local mem1 = collectgarbage 'count'
local e1 = {}
for i = 1, 100 do
    local e2 = {}
    e1['xxx' .. i] = e2
    for j = 1, 100 do
        e2['yyy' .. j] = 'zzz'
    end
end
collectgarbage()
collectgarbage()
local mem2 = collectgarbage 'count'
local e0 = lazy.build(e1):entry()
collectgarbage()
collectgarbage()
local mem3 = collectgarbage 'count'
for i = 1, 100 do
    e0['xxx' .. i]['x'] = true
end
collectgarbage()
collectgarbage()
local mem4 = collectgarbage 'count'

print(mem2 - mem1, mem3 - mem2, mem4 - mem3)
collectgarbage 'restart'

local cache = cacher('temp')
cache.maxFileSize = 1 * 1024 * 1024 -- 1MB
assert(cache)
e0 = lazy.build(e1, cache:writterAndReader 'e'):entry()
assert(#e1 == #e0)

local f1 = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
local f2 = { 'xx' }
f1.x = f2
local f0 = lazy.build(f1):exclude(f2):entry()
assert(util.equal(f1, f0))

local g1 = { 1, function() end }
local g0 = lazy.build(g1):entry()
assert(util.equal(g1, g0))

local h1 = { 1, 2 }
local builder = lazy.build(h1, cache:writterAndReader 'h')
local h0 = builder:entry()
h1.x = 0
h0.x = 0
assert(util.equal(h1, h0))

local wt = setmetatable({}, {__mode = 'kv'})
wt[builder] = true
---@diagnostic disable-next-line: cast-local-type
builder = nil
collectgarbage()
collectgarbage()
assert(not next(wt))

local i1 = {}
local i0 = lazy.build(i1, cache:writterAndReader 'i'):entry()
assert(util.equal(i1, i0))

local j1 = {}
for x = 1, 10 do
    j1[x] = {}
    for y = 1, 10 do
        j1[x][y] = {}
        for z = 1, 10 do
            j1[x][y][z] = 0
        end
    end
end
local j0 = lazy.build(j1, cache:writterAndReader 'j'):entry()
for i = 1, 10 do
    for x = 1, 10 do
        for y = 1, 10 do
            for z = 1, 10 do
                assert(j0[x][y][z] == i - 1)
                j0[x][y][z] = i
            end
        end
    end
end

print('测试通过')
