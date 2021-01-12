local fsu  = require 'fs-utility'
local fs   = require 'bee.filesystem'
local mini = require 'minitable'
local util = require 'utility'

debug.getmetatable('').__lt = function (a, b)
    local tpa = type(a)
    local tpb = type(b)
    if tpa == 'number' then
        return true
    end
    if tpb == 'number' then
        return false
    end
    return false
end

local tablePath = fs.path [[C:\W3-Server\local-resource\table]]

local clock1 = os.clock()
local mem1   = collectgarbage 'count'
print(clock1, mem1)
local tables = {}
local listfile = dofile((tablePath / 'listfile.lua'):string())
for _, fileName in ipairs(listfile) do
    local path = tablePath / fileName
    if fileName:find('grass', 1, true) then
        print('忽略文件：', fileName)
    else
        tables[#tables+1] = dofile(path:string())
    end
end

local clock2 = os.clock()
local mem2   = collectgarbage 'count'
print(clock2, mem2)
collectgarbage()
collectgarbage()
local clock3 = os.clock()
local mem3   = collectgarbage 'count'
print(clock3, mem3)

collectgarbage()
collectgarbage()

local clock5 = os.clock()
local mem5   = collectgarbage 'count'
print(clock5, mem5)

local info = mini.mini(tables, 2)
local clock6 = os.clock()
collectgarbage()
collectgarbage()
local mem6   = collectgarbage 'count'
print('mini1后', clock6, mem6)

local script = mini.dump(info)
util.saveFile('temp/dump', script)
local clock8 = os.clock()
print('Load Table前', clock8)
local new2 = assert(load(script))()
local clock9 = os.clock()
print('Load Table后', clock9)

local new = mini.build(info)
print(collectgarbage 'count')
local clock7 = os.clock()
collectgarbage()
collectgarbage()
local mem7   = collectgarbage 'count'
print('build后', clock7, mem7)

if not util.equal(tables, new) then
    print('不相等 #11！')
    --util.saveFile('temp/a', util.dump(tables))
    --util.saveFile('temp/b', util.dump(new))
end
if not util.equal(new, tables) then
    print('不相等 #12！')
end

if not util.equal(tables, new2) then
    print('不相等 #21！')
    --util.saveFile('temp/a', util.dump(tables))
    --util.saveFile('temp/b', util.dump(new2))
end
if not util.equal(new2, tables) then
    print('不相等 #22！')
end

if not util.equal(new, new2) then
    print('不相等 #31!')
end
if not util.equal(new2, new) then
    print('不相等 #32!')
end

local clock10 = os.clock()
mini.dump(mini.mini(tables, 2))
local clock11 = os.clock()
print('耗时', clock11 - clock10)

script = nil
tables = nil
info = nil
new = nil
--new2 = nil

collectgarbage()
collectgarbage()
local mem999 = collectgarbage 'count'
print('最终内存：', mem999)
