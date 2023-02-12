--[[=============================================--
-- main.lua
-- Main bot entrypoint
--
--
-- SPDX-License-Identifier: GPL-3.0-only
-- Author: Lyrthras
--=============================================]]--

local fs = require 'coro-fs'

---@type discordia
local discordia = require 'discordia'

require 'discordia-llslash'
local client = discordia.Client()

local util = require 'util'
local c = require 'commands'
local slashCommands = c.slashCommands
local slashHandlers = c.handlers


--=============================================--
-- Discord listeners

client:on('ready', function()
    client:info("Logged in as %s", client.user.username)

    local sl, err = client:bulkOverwriteApplicationCommands(slashCommands)
    if not sl then
        util.sendErrorToOwner(client, "Slash commands registration error: " .. err)
        return client:error("Slash commands registration error: %s", err)
    end
    client:info("Registered %d/%d global slash commands.", #slashCommands, #sl)
end)

client:on('slashCommand', function(intr)
    local command = slashHandlers[intr.data.name]
    if not command then
        return client:warning("Unknown slash command received: '/%s'", intr.data.name)
    end
    local ok, err = xpcall(command, debug.traceback, intr)
    if not ok then
        util.sendErrorToOwner(client, err)
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

local token = assert(fs.readFile('_token.txt'), "Missing token, place bot token into _token.txt")
client:run(('Bot %s'):format(token:gsub('%s+$', '')))
