
---@type SlashCommandDef
local cmd = {
    name = "test",
    description = "Super secret test command!",
    options = {
        {
            name = "channel",
            description = "Channel",
            required = false,
            type = 7,
        }
    },
    dm_permission = false,
}


function cmd.handle(intr)
    if intr.user.id ~= '368727799189733376' then intr:reply('No lol', true) return end

    intr:reply("Done!")
end


return cmd
