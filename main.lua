--[[=============================================--
-- main.lua
-- Main bot entrypoint
--
--
-- SPDX-License-Identifier: GPL-3.0-only
-- Author: Lyrthras
--=============================================]]--

local fs = require 'fs'

---@type discordia
local discordia = require 'discordia'

require 'discordia-llslash'
local client = discordia.Client()


local c = require 'commands'
local slashCommands = c.slashCommands
local slashHandlers = c.handlers


--=============================================--
-- Discord listeners

client:on('ready', function()
    client:info("Logged in as %s", client.user.username)

    local sl, err = client:bulkOverwriteApplicationCommands(slashCommands)
    if not sl then
        return client:error("Slash commands registration error: %s", err)
    end
    client:info("Registered %d/%d global slash commands.", #slashCommands, #sl)
end)

client:on('slashCommand', function(intr)
    local command = slashHandlers[intr.data.name]
    if not command then
        return client:warning("Unknown slash command received: '/%s'", intr.data.name)
    end
    local ok, err = pcall(command, intr)
    if not ok then
        return client:error("Slash command '/%s' error: %s", intr.data.name, err)
    end
end)


--=============================================--
-- Process listeners

process:on('sigint', function()
    print("Ctrl-C interrupt received.")
    process:exit()
end)

process:on('exit', function()
    print("Quitting...")
end)


--=============================================--
-- Run the bot

local token = assert(fs.readFileSync('_token.txt'), "Missing token, place bot token into _token.txt")
client:run(('Bot %s'):format(token:gsub('%s+$', '')))
