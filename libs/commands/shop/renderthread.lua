
local function __thread__(_sectionsSorted) coroutine.wrap(function()
    local require = require("require")(require"uv".cwd().."/thread")
    local fn = function()
        local json = require 'json'

        local util = require 'util'
        local logins = require 'ctlogins'
        local ShopRenderer = require 'commands/shop/shoprenderer'

        ShopRenderer.setup()
        local ct = logins.getMain()

        local sectionsSorted = util.jsonAssert(json.decode(_sectionsSorted))

        local footer = ShopRenderer.imageText('Footer', 'Century Shop Display beta. Displayed items may or may not accurately represent actual in-game items. Assets used are © 2023 Playwing.')
        local i = 0
        while i < #sectionsSorted do
            i = i + 1
            local sectionNameId, sets = sectionsSorted[i][1], sectionsSorted[i][2]

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
                if #items > #excess + 1 then
                    for _ = 1, math.floor((#items - #excess)/2) do
                        table.insert(excess, 1, table.remove(items))
                    end
                end
                table.insert(sectionsSorted, i+1, {sectionNameId, {excess}})
            end

            local shopTitle
            if sectionNameId:find('\1') then
                local x = sectionNameId:find('\1')
                local prefix, name = sectionNameId:sub(1,x-1), sectionNameId:sub(x+1)
                shopTitle = prefix .. (ct:getLocalization('MENU', name) or 'Other')
            else
                shopTitle = ct:getLocalization('MENU', sectionNameId) or 'Other'
            end
            local imVars = {
                ShopTitle = ShopRenderer.imageText('ShopTitle', shopTitle),
                Footer = footer,
                CarouselConfig = { centered = true, maxcols = 6, xpad = 40 },
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

                ::continue::
            end

            ShopRenderer.generate(imVars, 'storage/Shop'..i..'.png')
        end

        require'fs'.writeFileSync('storage/shop.done', tostring(#sectionsSorted))
    end

    local succ, err = xpcall(fn, debug.traceback)
    if not succ then
        require'fs'.writeFileSync('storage/shop.done', '-1\t'..err)
    end
end)() end


local fs = require 'fs'
local json = require 'json'
local thread = require 'thread'

return function(sectionsSorted)
    fs.unlinkSync('storage/shop.done')
    local _sectionsSorted = json.encode(sectionsSorted)

    return thread.start(__thread__, _sectionsSorted)
end
