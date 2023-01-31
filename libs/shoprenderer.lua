--[[=============================================--
-- shoprenderer.lua
-- SVG renderer and parser for shop image generation
--
--
-- SPDX-License-Identifier: GPL-3.0-only
-- Author: Lyrthras
--=============================================]]--

local fs = require 'fs'
local base64 = require 'base64'

local vips = require 'vips'
local slaxml = require 'slaxdom'


---

local layoutDir = 'layouts'


---

local function pesc(str)
    return (str:gsub("([^%w])", "%%%1"))
end

local function imageText(name, value)
    local svg = assert(fs.readFileSync(('%s/Text%s.svg'):format(layoutDir, name)))
    svg = svg:gsub('{{$'..pesc(name)..'}}', pesc(tostring(value)))
    return vips.Image.new_from_buffer(svg, "dpi=75")
end

local function imageLongDesc(text)
    local image = vips.Image.text(text, {width = 512, dpi = 75, font="LT Museum 24"})
    local overlay = image:new_from_image {0xD0, 0xD0, 0xD0}:copy {interpretation = 'srgb'}
    overlay = overlay:bandjoin(image)
    return overlay
end

local function imageBinary(str)
    return vips.Image.new_from_buffer(str)
end

local function depth(node)
    local ndepth = 0
    local parent = node.parent
    while parent do
        parent = parent.parent
        ndepth = ndepth + 1
    end
    return ndepth
end



-- <image id="image1_0_1" data-name="ShopTitleBg.png" width="1144" height="236" xlink:href="res/ShopTitleBg.png"/>
-- attrs is {{'key1', 'val1'}, {'key2', 'val2'}, ...}
local function makeElement(name, attrs)
    local elem = {
        type = 'element',
        name = name,
        kids = {},
        el = {}
    }
    local attr = {}
    for i,v in ipairs(attrs) do
        attr[i] = {
            type = 'attribute',
            name = v[1],
            value = v[2],
            parent = elem
        }
        attr[v[1]] = v[2]
    end

    elem.attr = attr
    return elem
end

local function getCenteredOffset(rectX, rectY, rectW, rectH, imgW, imgH)
    return (rectX+rectX+rectW-imgW)/2, (rectY+rectY+rectH-imgH)/2
end


local ops = {}

local function search(node, cb)
    if not node.kids then return end
    for i,ch in ipairs(node.kids) do
        cb(ch)
        if node.kids[i].kids then
            search(node.kids[i], cb)
        end
    end
end

local function parse(dom, varstb)
    search(dom, function(node)
        if node.attr and node.attr.id then
            local opName, opArg = node.attr.id:match('{{([^$=]+)=([^}]+)}}')
            if opName then
                local args = {}
                for arg in opArg:gmatch('[^,]+') do
                    args[#args+1] = arg
                end
                if ops[opName] then
                    ops[opName](args, node, varstb)
                end
            end
        end
    end)
end

function ops.REI(args, node, varstb)
    local varName = table.remove(args, 1)
    for i in ipairs(args) do args[table.remove(args, i):lower()] = true end

    local im = varstb[varName]
    if type(im) == 'table' and im.vimage then
        local x, y = tonumber(node.attr.x or 0), tonumber(node.attr.y or 0)
        local w, h = tonumber(im:width()), tonumber(im:height())
        local rw, rh = tonumber(node.attr.width), tonumber(node.attr.height)

        local fac = math.min(args.limitw and rw/w or 1, args.limith and rh/h or 1)
        if fac < 0.99 then
            im = im:resize(fac)
            w, h = tonumber(im:width()), tonumber(im:height())
        end

        if args.center then
            x, y = getCenteredOffset(x, y, rw, rh, w, h)
        end

        slaxml:replace(node, makeElement('image', {
            {'x', tostring(x)},
            {'y', tostring(y)},
            {'width', tostring(w)},
            {'height', tostring(h)},
            {'href', 'data:image/png;base64,'..base64.encode(tostring(im:write_to_buffer(".png")))}
        }))

        varstb[varName] = nil
        collectgarbage()
        collectgarbage()
    end
end

function ops.REP(args, node, varstb)
    local filename, config, varsArray = args[1], varstb[args[2]], varstb[args[3]]
    if not config or not varsArray then
        error("Misconfigured REP: missing _CONFIGVAR_ or _VARSTABLEVAR_")
    end

    local _svg = assert(fs.readFileSync(('%s/%s'):format(layoutDir, filename)))
    local _dom = slaxml:dom(_svg, { stripWhitespace = true })

    local n = #varsArray

    -- flow: l->r, t->b
    local cols, rows = (config.maxcols or 256), (config.maxrows or 256)
    if n <= cols then
        cols = n
        rows = 1
    else
        rows = math.min(rows, math.ceil(n / cols))
    end
    if n > rows*cols then print(('warning: too many elements (%s elements in %sx%s)'):format(n, cols, rows)) end

    local x, y = tonumber(node.attr.x or 0), tonumber(node.attr.y or 0)
    local w, h = tonumber(_dom.root.attr.width), tonumber(_dom.root.attr.height)
    if not w or not h then error(filename.." does not have width/height fields") end

    local lw = (cols*w) + ((cols-1)*(config.xpad or 10))
    local lh = (rows*h) + ((rows-1)*(config.ypad or 10))
    local cw = w + (config.xpad or 10)
    local ch = h + (config.ypad or 10)

    if config.centered then
        local rw, rh = tonumber(node.attr.width), tonumber(node.attr.height)
        x, y = getCenteredOffset(x, y, rw, rh, lw, lh)
    end

    local newNode = makeElement('g', {})
    slaxml:replace(node, newNode)

    for i,vars in ipairs(varsArray) do
        -- is both 0 index
        local col, row = (i-1) % cols, math.floor((i-1) / cols)
        if row > rows then goto continue end
        local ix, iy = x + col*cw, y + row*ch

        local newDom = slaxml:clone(_dom)
        slaxml:attr(newDom.root, nil, 'x', tostring(ix))
        slaxml:attr(newDom.root, nil, 'y', tostring(iy))

        search(newDom.root, function(node1)
            if node1.attr and node1.attr.id then
                search(newDom.root, function(n2)
                    if n2.attr then
                        for _,v in ipairs {'clip-path', 'href', 'fill'} do
                            if n2.attr[v]
                                and n2.attr[v]:find(pesc(node1.attr.id))
                                and not n2.attr[v]:find(pesc(node1.attr.id)..'[A-Za-z0-9_-]')
                                and not n2.attr[v]:find(pesc(node1.attr.id)..'__svg_'..i) then
                                slaxml:attr(n2, nil, v, n2.attr[v]:gsub(pesc(node1.attr.id), pesc(node1.attr.id)..'__svg_'..i))
                            end
                        end
                    end
                end)
                slaxml:attr(node1, nil, 'id', node1.attr.id..'__svg_'..i)
            end
        end)
        parse(newDom, vars)

        slaxml:reparent(newDom.root, newNode)

        ::continue::
    end
end

function ops.SEL(args, node, varstb)
    local propName = args[1]
    local propVal = varstb[propName]
    if not propVal then error(propName..' is unspecified') end
    local ch = node.kids
    if not ch then return end
    if ch[1] and ch[1].kids and ch[1].attr and not ch[1].attr.id then ch = ch[1].kids end

    local toRemove = {}
    for _,v in ipairs(ch) do
        if not v.attr or not v.attr.id or not v.attr.id:find('^'..pesc(propName)..'='..pesc(propVal)) then
            toRemove[#toRemove+1] = v
        end
    end
    if #ch == #toRemove then toRemove[#toRemove] = nil end
    for _,v in ipairs(toRemove) do
        slaxml:remove(v)
    end

    slaxml:attr(node, nil, 'id', node.attr.id:gsub('{{SEL='..pesc(propName)..'}}', ''))
end


---


local svg = nil

---@class ShopRenderer
local ShopRenderer = {}

function ShopRenderer.setup()
    if svg then return end
    -- load the font files for vips to use
    vips.Image.text(".", {width = 512, font="LT Museum", fontfile=layoutDir..'/fonts/LTMuseum-Reg.ttf'})
    vips.Image.text(".", {width = 512, font="LT Museum", fontfile=layoutDir..'/fonts/LTMuseum-Bold.ttf'})
    vips.Image.text(".", {width = 512, font="LT Museum", fontfile=layoutDir..'/fonts/LTMuseum-Ital.ttf'})

    svg = assert(fs.readFileSync(layoutDir..'/MainArea.svg'))
end

function ShopRenderer.generate(vars, outPath)
    ShopRenderer.setup()
    local dom = slaxml:dom(svg, { stripWhitespace = true })
    parse(dom, vars)
    local xml = slaxml:xml(dom)
    fs.writeFileSync(layoutDir..'/result.svg', xml)
    vips.Image.new_from_file(layoutDir..'/result.svg'):write_to_file(outPath)
end

ShopRenderer.imageBinary = imageBinary
ShopRenderer.imageText = imageText
ShopRenderer.imageLongDesc = imageLongDesc


return ShopRenderer
