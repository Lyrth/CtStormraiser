
---@type SlashCommandDef
local cmd = {
    name = "shop",
    description = "Shows the current Century shop contents.",
    options = {},
    dm_permission = false,
}


local discordia = require 'discordia'
local json = require 'json'
local fs = require 'fs'

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

local tl = assert(json.decode(assert(fs.readFileSync 'resources/Game.locres.json')))
local function getloc(ns, key, emptyMissing)
    local n = tl[ns]
    if not n then return ("[NS_ERR:%s]"):format(ns) end
    return (n[key] or (emptyMissing and '' or ("%s|%s"):format(ns, key))):gsub('<[^>]*>(.-)</>', '%1'):gsub('<[^>]*>', '?')
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
}


-- TODO Stickers
-- 1 - BEST VALUE
-- 2 - Discount
-- 4 - NEW

local shopres = assert(fs.readFileSync 'resources/testresponse.json')

function cmd.handle(intr)
    if intr.user.id ~= '368727799189733376' then intr:reply('No lol', true) return end

    local shop = json.decode(shopres).data.FunctionResult.Store     -- todo fetch

    local sections = {}
    for _,v in ipairs(shop) do
        if sectionNames[v.Section] then
            if not v.Name then v.Name = sectionNames[v.Section] end
            if v.Slot == 256 or v.Slot == 272 then v.Slot = 1 end
            if not sections[v.Name] then sections[v.Name] = {} end
            local slot = sections[v.Name][v.Slot+1]
            if not slot then
                slot = {}
                sections[v.Name][v.Slot+1] = slot
            end
            slot[#slot+1] = {
                id = v.ID,
                date = v.Date,
                RM = v.RM, SC = v.SC, HC = v.HC
            }
        end
    end

    local fields = {}
    for sectionNameId, sets in pairs(sections) do
        fields[#fields+1] = {}
        local field = fields[#fields]
        local sectionTitle = getloc('MENU', sectionNameId, true)
        field.name = #sectionTitle > 0 and sectionTitle or 'Other'
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
                local name = getloc('PACKAGE', item.id..'_NAME')
                local desc = getloc('PACKAGE', item.id..'_DESC', true)
                local prices = {}
                prices[#prices+1] = item.RM and ('$'..(item.RM/100)) or nil
                prices[#prices+1] = item.SC and (item.SC..' Coins') or nil
                prices[#prices+1] = item.HC and (item.HC..' Gems') or nil
                local price = table.concat(prices, ' / ')
                field.value = field.value .. (" • _%s_ %s- %s%s\n"):format(
                    name,
                    #desc == 0 and '' or ('(%s) '):format(desc),
                    price,
                    item.date == commonDate and '' or (' - %s'):format(formatDate(commonDate))
                )
            end

            field.value = field.value .. '\n'
        end
    end

    intr:reply {
        embed = {
            title = "Century Shop",
            description = "test",
            fields = fields,
            --footer = {text = "This is a footer", icon_url = "https://www.google.com/favicon.ico",
            color = discordia.Color.fromRGB(120, 40, 180).value,
        }
    }
end


return cmd
