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

local DB = require 'storage/db'
local config = DB:open 'config/shop'
local ct = logins.getMain()


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

local function updateLastState(lastState, hash)
    local empty = config:get {'lastUpdate'} == nil
    local storedItems, needUpdate
    local storedHash = util.b64decode(config:get {'lastUpdate', 'hash', default = ''})
    if storedHash == hash then
        lastState.time = tonumber(config:get {'lastUpdate', 'time', default = os.time()})
        lastState.currentNew = config:get {'lastUpdate', 'currentNew', default = {}}
    else
        lastState.time = os.time()
        lastState.currentNew = {}
        config:set {'lastUpdate', 'time', value = lastState.time}
        storedItems = config:get {'lastUpdate', 'items', default = empty and {} or nil}
        needUpdate = true
    end

    return storedItems, storedItems and needUpdate or false
end

local function parseShop(shop, previousItems, currentNew)
    local newItems = {}
    local sections = {}
    local firstSectionNames = {}
    for _,v in ipairs(shop) do
        if sectionNames[v.Section] then
            if not v.Name then v.Name = sectionNames[v.Section] end
            if firstSectionNames[v.Section] then
                v.Name = firstSectionNames[v.Section]
            else
                firstSectionNames[v.Section] = v.Name
            end
            if v.Slot == 256 or v.Slot == 272 then
                v.Slot = 0
                v.Square = true
            end
            if v.Section:sub(1,2) == 'EX' then
                v.Name = 'Weekly - \1'..v.Name
            end
            if not sections[v.Name] then sections[v.Name] = {} end
            local slot = sections[v.Name][v.Slot+1]
            if not slot then
                slot = {}
                sections[v.Name][v.Slot+1] = slot
            end
            newItems[#newItems+1] = v.ID
            slot[#slot+1] = {
                id = v.ID,
                date = v.Date,
                RM = v.RM or 0, SC = v.SC or 0, HC = v.HC or 0,
                square = v.Square,
                forceDaily = v.Name:find('DailySectionTitle') ~= nil,
                isNew = util.contains(currentNew, v.ID) or (previousItems and not util.contains(previousItems, v.ID))
            }
        end
    end

    local sorted = {}
    for sectionNameId, sets in pairs(sections) do
        sorted[#sorted+1] = {sectionNameId, sets}
    end
    table.sort(sorted, function(a,b) return a[1] < b[1] end)

    return sorted, newItems
end

local function makeFields(lastState, sections)
    local fields = {}
    for _,v in ipairs(sections) do
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
                for i, item in ipairs(set) do
                    if item.forceDaily then
                        local today = os.date('!*t', lastState.time > 0 and lastState.time or os.time())
                        -- Hmm. March 31 + 1 = March 32? This is fine.
                        item.date = os.time {day = today.day + 1, month = today.month, year = today.year, hour = 0} + util.getTzOffset()
                    end
                    dates[i] = item.date
                end
                commonDate = smode(dates)
            end
            field.value = field.value .. ("Set %d %s:\n"):format(setId, formatDate(commonDate))

            for _, item in ipairs(set) do
                local name = ct:getLocalization('PACKAGE', item.id..'_NAME') or '???'
                local desc = ct:getLocalization('PACKAGE', item.id..'_DESC') or ''
                field.value = field.value .. (" • _%s_%s%s%s\n"):format(
                    name,
                    #desc == 0 and '' or (' - %s'):format(desc),
                    item.date == commonDate and '' or (' - %s'):format(formatDate(commonDate)),
                    item.isNew and ' *[NEW]*' or ''
                )
            end

            field.value = field.value .. '\n'
        end
    end

    return fields
end

local function renderSections(sections)
    render(sections)

    -- TODO proper communication
    local timeout = false
    timer.setTimeout(60000, function() timeout = true end)
    while not timeout and not fs.access('storage/shop.done', 'r') do
        timer.sleep(1000)
    end
    local n, err = assert(fs.readFile('storage/shop.done')):match('^([-%d]+)%s*(.*)$')
    if tonumber(n) < 0 then error(err) end
    return n
end

local function sendShop(msg, lastState)
    msg:update(lastState.embed)

    do
        local files = {}
        for i = 1, lastState.numFiles do
            files[#files+1] = {('CtBot_Shop%02d_%s.png'):format(i, os.date('!%Y-%m-%d')), fs.readFile('storage/Shop'..i..'.png')}
            if #files >= 8 and #files < lastState.numFiles then
                msg.channel:send {files = files}
                files = {}
            end
        end
        msg.channel:send {files = files}
    end

    collectgarbage()
    collectgarbage()
end



local lastState = {
    time = 0,
    hash = '',
    embed = nil,
    numFiles = 0,
    currentNew = {},
}

local function run(channel, msg)
    local shop = assert(ct:getShop())
    local hash = util.tbHash(shop)

    if hash == lastState.hash and lastState.embed then
        lastState.embed.embed.description = ("Century shop contents as of <t:%d:F>\nLast checked: <t:%d:R>\n_ _"):format(lastState.time, os.time())
        -- if there's no message, means we're doing automated. Don't do anything on automated
        if msg then sendShop(msg, lastState) end
        return
    end

    ---
    if msg then
        msg:setContent("Processing...")
    else
        msg = channel:send("Processing...")
    end

    local oldItems, updateItems = updateLastState(lastState, hash)
    local sections, newItems = parseShop(shop, oldItems, lastState.currentNew)
    if updateItems then
        local currentNew = {}
        for _,v in ipairs(newItems) do
            if not util.contains(oldItems, v) then
                currentNew[#currentNew+1] = v
            end
        end
        lastState.currentNew = currentNew
        config:set {'lastUpdate', 'currentNew', value = currentNew}
        config:set {'lastUpdate', 'items', value = newItems}
    end

    local embed = {
        content = 'Generating item displays...',
        embed = {
            title = "Century Shop",
            description = ("Century shop contents as of <t:%d:F>\nLast checked: <t:%d:R>\n_ _"):format(lastState.time, os.time()),
            fields = makeFields(lastState, sections),
            --footer = {text = "This is a footer", icon_url = "https://www.google.com/favicon.ico",
            color = discordia.Color.fromRGB(120, 40, 180).value,
        }
    }
    msg:update(embed)

    local n = renderSections(sections)

    lastState.hash = hash
    lastState.embed = embed
    lastState.embed.content = ''
    lastState.numFiles = tonumber(n)
    config:set {'lastUpdate', 'hash', value = util.b64encode(hash)}

    sendShop(msg, lastState)
end

function cmd.handle(intr)
    if intr.user.id ~= '368727799189733376' then intr:reply('No lol', true) return end
    intr:reply("Ok", true)

    run(nil, intr.channel:send("Fetching shop..."))
end


return cmd
