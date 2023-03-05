
---@type SlashCommandDef
local cmd = {
    name = "status_channel",
    description = "View or set the status channel for the bot.",
    options = {
        {
            name = "channel",
            description = "Channel to send bot status on.",
            required = false,
            type = 7,
        }
    },
    dm_permission = false,
}


local class = require 'discordia'.class

local config = require 'storage/db':open 'config/keepalive'

function cmd.handle(intr)
    if intr.user.id ~= '368727799189733376' then intr:reply('No lol', true) return end

    if not intr.data.options or not intr.data.options[1] then
        local current = config:get('channel')
        intr:reply("Current status channel: " .. (current and "<#"..current..">" or "None"))
        return
    end

    local opt1 = intr.data.options[1]
    assert(opt1.name == 'channel', "Invalid options form received: channel")
    local channelId = opt1.value

    local ch = intr.guild:getChannel(channelId)
    if class.type(ch) ~= 'GuildTextChannel' then
        intr:reply("Not a valid text channel!")
        return
    end

    config:set('channel', channelId)

    intr:reply("Done!")
end


return cmd
