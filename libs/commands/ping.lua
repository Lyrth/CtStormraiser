
---@type SlashCommandDef
local cmd = {
    name = "ping",
    description = "Checks bot ping.",
    options = {},
    dm_permission = false,
}

function cmd.handle(intr)
    intr:reply("Pinging...")
    local resp = intr:getReply()
    if resp then
        local interv = (resp.createdAt - intr.createdAt) * 1000
        resp:setContent(("Pong! Response time: `%.fms`"):format(interv))
    end
end


return cmd
