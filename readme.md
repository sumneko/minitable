# Compress read only Lua table

## usage
```lua
local minitable = require 'minitable'
local info = minitable.mini(myTable, 2)

-- Create a compressed table
local newTable = minitable.build(info)

-- Create a script, loading this script to create a compressed table
local dump = minitable.dump(info)
local newTbale = load(dump)
```

## mini level
* 0: No compression
* 1: Optimize objects with the same content
* 2: Optimize objects with the same fields (Minimal runtime overhead)

## test

The compression effect will be affected by the structure of the table.

The following is my test result of an automatically generated data table.

> Memory

| mini level | Lua 5.1 | Lua 5.2 | Lua 5.3 | Lua 5.4 |
| ---------- | ------- | ------- | ------- | ------- |
| 0          |  55.1m  |  52.5m  |  44.7m  |  36.9m  |
| 1          |  25.6m  |  24.4m  |  20.7m  |  17.0m  |
| 2          |  16.2m  |  15.2m  |  13.3m  |  11.4m  |

> Full GC

| mini level | Lua 5.1 | Lua 5.2 | Lua 5.3 | Lua 5.4 |
| ---------- | ------- | ------- | ------- | ------- |
| 0          | 16.74ms | 16.36ms | 16.42ms | 16.28ms |
| 1          | 05.03ms | 04.92ms | 04.97ms | 04.93ms |
| 2          | 04.17ms | 04.35ms | 04.27ms | 04.35ms |
