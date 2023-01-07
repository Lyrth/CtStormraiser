
local fs = require 'fs'

---@type discordia
local discordia = require 'discordia'
local client = discordia.Client()

--=============================================--

client:on('ready', function()
    client:info("Logged in as %s", client.user.username)
end)

--=============================================--

-- Run the bot
local token = assert(fs.readFileSync('_token.txt'), "Missing token, place bot token into _token.txt")
client:run(('Bot %s'):format(token:gsub('%s+$', '')))
