
---@class TaskDef
---@field name string
---@field every integer
---@field setup fun(client: Client, seq: 0)
---@field run fun(client: Client, seq: integer)

-- File names for each command
local tasks = {
    'keepalive',
    'test',
}


local timer = require 'timer'

local cron = {}
cron.timers = {}

function cron.setup(client)
    for _, filename  in ipairs(tasks) do
        ---@type boolean, TaskDef
        local ok, task = pcall(require, './'..filename)
        if ok then
            coroutine.wrap(task.setup)(client, 0)

            local seq = 0
            cron.timers[task.name] = timer.setInterval(task.every, function()
                seq = seq + 1
                coroutine.wrap(task.run)(client, seq)
            end)
        else
            print("WARNING: task '"..filename..".lua' not found.\n")
        end
    end
end

-- todo stop

return cron
