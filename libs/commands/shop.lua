--[[=============================================--
-- shop.lua
-- Century shop command
--
--
-- SPDX-License-Identifier: GPL-3.0-only
-- Author: Lyrthras
--=============================================]]--

---@type SlashCommandDef
local cmd = {
    name = "shop",
    description = "Shows the current Century shop contents.",
    options = {},
    dm_permission = false,
}


local discordia = require 'discordia'
local fs = require 'coro-fs'
local timer = require 'timer'

local util = require 'util'
local logins = require 'ctlogins'
local render = require 'commands/shop/renderthread'

local function smode(t)
    local counts = {}

    for _,v in pairs(t) do
        counts[v] = (counts[v] or 1) + 1
    end

    local biggestCount = 0
    local mode
    for k,v  in pairs(counts) do
        if v > biggestCount then
            biggestCount = v
            mode = k
        end
    end

    return mode
end

local function formatDate(timestamp)
    if timestamp < 0 then
        return "[No date]"
    end
    return ("ends <t:%d:R>"):format(timestamp)
end


local sectionNames = {
    LV1 = 'Other',
    LV2 = 'Other',
    EVT = 'EventSectionTitle',
    DAY = 'DailySectionTitle',
    FTD = 'FeaturedSectionTitle',
    EX1 = 'Weekly - Other',
    EX2 = 'Weekly - Other',
    EX3 = 'Weekly - Other',
}


-- TODO Stickers
-- 1 - BEST VALUE
-- 2 - Discount
-- 4 - NEW

local lastUpdate = 0
local lastHash = ''
local lastEmbed = nil
local numFiles = 0

function cmd.handle(intr)
    if intr.user.id ~= '368727799189733376' then intr:reply('No lol', true) return end

    intr:reply("Fetching shop...")
    intr._message = intr:getReply()

    local ct = logins.getMain()

    local shop = assert(ct:getShop())
    local hash = util.tbHash(shop)

    if hash == lastHash and lastEmbed then
        lastEmbed.embeds[1].description = ("Century shop contents as of <t:%d:F>\nLast checked: <t:%d:R>\n_ _"):format(lastUpdate, os.time())

        intr:editReply(lastEmbed)

        do
            local files = {}
            for i = 1, numFiles do
                files[#files+1] = {('CtBot_Shop%02d_%s.png'):format(i, os.date('!%Y-%m-%d')), fs.readFile('storage/Shop'..i..'.png')}
                if #files >= 8 and #files < numFiles then
                    intr.channel:send {files = files}
                    files = {}
                end
            end
            intr.channel:send {files = files}
        end

        collectgarbage()
        collectgarbage()
        return
    end

    intr:editReply("Processing...")

    local sections = {}
    for _,v in ipairs(shop) do
        if sectionNames[v.Section] then
            if not v.Name then v.Name = sectionNames[v.Section] end
            if v.Section:sub(1,2) == 'EX' then
                v.Name = 'Weekly - \1'..v.Name
            end
            if v.Slot == 256 or v.Slot == 272 then v.Slot = 1 v.Square = true end
            if not sections[v.Name] then sections[v.Name] = {} end
            local slot = sections[v.Name][v.Slot+1]
            if not slot then
                slot = {}
                sections[v.Name][v.Slot+1] = slot
            end
            slot[#slot+1] = {
                id = v.ID,
                date = v.Date,
                RM = v.RM or 0, SC = v.SC or 0, HC = v.HC or 0,
                square = v.Square
            }
        end
    end

    local sectionsSorted = {}
    for sectionNameId, sets in pairs(sections) do
        sectionsSorted[#sectionsSorted+1] = {sectionNameId, sets}
    end
    table.sort(sectionsSorted, function(a,b) return a[1] < b[1] end)

    local fields = {}
    for _,v in ipairs(sectionsSorted) do
        local sectionNameId, sets = v[1], v[2]
        fields[#fields+1] = {}
        local field = fields[#fields]
        if sectionNameId:find('\1') then
            local x = sectionNameId:find('\1')
            local prefix, name = sectionNameId:sub(1,x-1), sectionNameId:sub(x+1)
            field.name = prefix .. (ct:getLocalization('MENU', name) or 'Other')
        else
            field.name = ct:getLocalization('MENU', sectionNameId) or 'Other'
        end
        field.value = ''

        for setId, set in ipairs(sets) do
            local commonDate = -1
            do
                local dates = {}
                for i, item in ipairs(set) do dates[i] = item.date end
                commonDate = smode(dates)
            end
            field.value = field.value .. ("Set %d %s:\n"):format(setId, formatDate(commonDate))

            for _, item in ipairs(set) do
                local name = ct:getLocalization('PACKAGE', item.id..'_NAME') or '???'
                local desc = ct:getLocalization('PACKAGE', item.id..'_DESC') or ''
                field.value = field.value .. (" • _%s_%s%s\n"):format(
                    name,
                    #desc == 0 and '' or (' - %s'):format(desc),
                    item.date == commonDate and '' or (' - %s'):format(formatDate(commonDate))
                )
            end

            field.value = field.value .. '\n'
        end
    end


    lastUpdate = os.time()
    local embed = {
        content = 'Generating item displays...',
        embeds = {{
            title = "Century Shop",
            description = ("Century shop contents as of <t:%d:F>\nLast checked: <t:%d:R>\n_ _"):format(lastUpdate, os.time()),
            fields = fields,
            --footer = {text = "This is a footer", icon_url = "https://www.google.com/favicon.ico",
            color = discordia.Color.fromRGB(120, 40, 180).value,
        }}
    }
    intr:editReply(embed)

    render(sectionsSorted)
    local timeout = false
    timer.setTimeout(60000, function() timeout = true end)
    while not timeout and not fs.access('storage/shop.done', 'r') do
        timer.sleep(1000)
    end
    local n, err = assert(fs.readFile('storage/shop.done')):match('^([-%d]+)%s*(.*)$')
    if tonumber(n) < 0 then error(err) end

    lastHash = hash

    embed.content = ''
    lastEmbed = embed
    intr:editReply(lastEmbed)

    do
        local files = {}
        numFiles = tonumber(n)
        for i = 1, numFiles do
            files[#files+1] = {('CtBot_Shop%02d_%s.png'):format(i, os.date('!%Y-%m-%d')), fs.readFile('storage/Shop'..i..'.png')}
            if #files >= 8 and #files < numFiles then
                intr.channel:send {files = files}
                files = {}
            end
        end
        intr.channel:send {files = files}
    end

    collectgarbage()
    collectgarbage()
end


return cmd
