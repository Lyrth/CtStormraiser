
---@type TaskDef
local task = {
    name = 'test',
    every = 1000*300,
}


function task.setup(client)
    --print("task: On setup")
end

function task.run(client, seq)
    --print("task: On run, seq no "..seq)
end


return task
