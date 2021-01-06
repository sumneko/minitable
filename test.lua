local fsu  = require 'fs-utility'
local fs   = require 'bee.filesystem'
local mini = require 'minitable'
local util = require 'utility'

local tablePath = fs.path [[C:\W3-Server\local-resource\table\Data]]

local clock1 = os.clock()
local mem1   = collectgarbage 'count'
print(clock1, mem1)
local tables = {}
local dirMems = {}
for dir in tablePath:list_directory() do
    if fs.is_directory(dir) then
        collectgarbage()
        collectgarbage()
        local startMem = collectgarbage 'count'
        fsu.scanDirectory(dir, function (path)
            local text = fsu.loadFile(path)
            local f = load(text)
            local t = f()
            tables[#tables+1] = t
        end)
        collectgarbage()
        collectgarbage()
        local finishMem = collectgarbage 'count'
        dirMems[#dirMems+1] = {finishMem - startMem, dir}
    else
        local text = fsu.loadFile(dir)
        local f = load(text)
        local t = f()
        tables[#tables+1] = t
    end
end
table.sort(dirMems, function (a, b)
    return a[1] > b[1]
end)
for _, data in ipairs(dirMems) do
    --print(data[1], data[2])
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
print('设置空表后', clock5, mem5)

local info = mini.mini(tables, 0)
local clock6 = os.clock()
collectgarbage()
collectgarbage()
local mem6   = collectgarbage 'count'
print('mini1后', clock6, mem6)

local new = mini.build(info)
local clock7 = os.clock()
collectgarbage()
collectgarbage()
local mem7   = collectgarbage 'count'
print('build后', clock7, mem7)

if not util.equal(tables, new) then
    print('不相等！')
    util.saveFile('temp/a', util.dump(tables))
    util.saveFile('temp/b', util.dump(new))
end
