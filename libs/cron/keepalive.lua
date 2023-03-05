
---@type TaskDef
local task = {
    name = 'keepalive',
    every = 1000*14,
}


local config = require 'storage/db':open 'config/keepalive'

local lastChId
local lastMessage

function task.run(client, seq)
    local chId = config:get('channel')
    if not chId then return end

    if lastMessage and chId == lastChId then
        -- nothing changed
        lastMessage:setContent(tostring(seq))
        return
    end

    -- new channel detected
    local channel = client:getChannel(chId)
    if not channel then return end
    lastChId = chId
    lastMessage = channel:send("Bot status here: "..seq)
end

task.setup = task.run


return task
