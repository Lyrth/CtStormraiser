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
local fs = require 'fs'

local util = require 'util'
local logins = require 'ctlogins'
local ShopRenderer = require 'shoprenderer'

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
        lastEmbed.embeds[1].description = ("Last checked: <t:%d:R>\nLast updated: <t:%d:R>\n"):format(os.time(), lastUpdate)

        intr:editReply(lastEmbed)

        local files = {}
        for i = 1, numFiles do
            files[#files+1] = {('CtBot_Shop%02d_%s.png'):format(i, os.date('!%Y-%m-%d')), fs.readFileSync('storage/Shop'..i..'.png')}
        end
        intr.channel:send {files = files}
        return
    end

    intr:editReply("Processing...")

    local sections = {}
    for _,v in ipairs(shop) do
        if sectionNames[v.Section] then
            if not v.Name then v.Name = sectionNames[v.Section] end
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
        field.name = ct:getLocalization('MENU', sectionNameId) or 'Other'
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
                field.value = field.value .. (" • _%s_ %s%s\n"):format(
                    name,
                    #desc == 0 and '' or ('(%s) '):format(desc),
                    item.date == commonDate and '' or (' - %s'):format(formatDate(commonDate))
                )
            end

            field.value = field.value .. '\n'
        end
    end


    local embed = {
        content = 'Generating item displays...',
        embeds = {{
            title = "Century Shop",
            description = ("Last checked: <t:%d:R>\nLast updated: <t:%d:R>\n_ _\n_ _"):format(os.time(), os.time()),
            fields = fields,
            --footer = {text = "This is a footer", icon_url = "https://www.google.com/favicon.ico",
            color = discordia.Color.fromRGB(120, 40, 180).value,
        }}
    }
    intr:editReply(embed)


    local footer = ShopRenderer.imageText('Footer', 'Century Shop Display beta. Displayed items may or may not accurately represent actual in-game items. Assets used are © 2023 Playwing.')
    for i,v in ipairs(sectionsSorted) do
        do
            local sectionNameId, sets = v[1], v[2]

            local items = {}
            local excess = {}

            for _,set in ipairs(sets) do
                for _, item in ipairs(set) do
                    if #items < 6 then
                        items[#items+1] = item
                    else
                        excess[#excess+1] = item
                    end
                end
            end
            if #excess > 0 then
                table.insert(sectionsSorted, i+1, {sectionNameId, {excess}})
            end


            local shopTitle = ct:getLocalization('MENU', sectionNameId) or 'Other'
            local imVars = {
                ShopTitle = ShopRenderer.imageText('ShopTitle', shopTitle),
                Footer = footer,
                CarouselConfig = { centered = true, maxcols = 6, xpad = 80 },
                Items = {}
            }


            for _, item in ipairs(items) do
                local pkg = ct:getPackageInfo(item.id)
                if not pkg then goto continue end
                local name = ct:getLocalization('PACKAGE', item.id..'_NAME') or '???'
                local desc = ct:getLocalization('PACKAGE', item.id..'_DESC') or ' '
                local longDesc = {}
                longDesc[#longDesc+1] = ct:getLocalization('PACKAGE', item.id..'_SPECDESC')
                longDesc[#longDesc+1] = ct:getLocalization('PACKAGE', item.id..'_CONTENT')

                local contType = item.square and 'Square' or 'Vert'
                local thumbName = pkg.texPaths.ShopMenuIcon and pkg.texPaths.ShopMenuIcon:match('[^.]+$') or (contType .. 'Placeholder')
                local vars = {
                    ThumbImage = ShopRenderer.imageBinary(ct:getThumbnail(thumbName .. '.png')),
                    ItemTitle = ShopRenderer.imageText('ItemTitle', util.locresFmt(name:upper())),
                    ItemDescShort = ShopRenderer.imageText('ItemDescShort', util.locresFmt(desc)),
                    ItemDescLong = ShopRenderer.imageLongDesc(util.locresFmt(table.concat(longDesc, '\n\n'))),
                    ContainerType = contType,
                    Rarity = pkg.rarity,
                }
                imVars.Items[#imVars.Items+1] = vars

                if item.RM > 0 or (item.SC == 0 and item.HC == 0) then
                    vars.PriceType = 'None'
                    vars.RealPrice = ShopRenderer.imageText('Price', item.RM == 0 and 'FREE' or ('€'..(item.RM/100)))
                elseif item.SC == 0 then
                    vars.PriceType = 'Gems'
                    vars.GemsPrice = ShopRenderer.imageText('Price', item.HC)
                elseif item.HC == 0 then
                    vars.PriceType = 'Coins'
                    vars.CoinsPrice = ShopRenderer.imageText('Price', item.SC)
                else
                    vars.PriceType = 'Both'
                    vars.CoinsPrice = ShopRenderer.imageText('Price', item.SC)
                    vars.GemsPrice = ShopRenderer.imageText('Price', item.HC)
                end
                collectgarbage()
                collectgarbage()

                ::continue::
            end

            ShopRenderer.generate(imVars, 'storage/Shop'..i..'.png')
        end
        collectgarbage()
        collectgarbage()
    end

    lastHash = hash

    embed.content = ''
    lastEmbed = embed
    intr:editReply(lastEmbed)

    local files = {}
    numFiles = #sectionsSorted
    for i = 1, numFiles do
        files[#files+1] = {('CtBot_Shop%02d_%s.png'):format(i, os.date('!%Y-%m-%d')), fs.readFileSync('storage/Shop'..i..'.png')}
    end
    intr.channel:send {files = files}
end


return cmd
