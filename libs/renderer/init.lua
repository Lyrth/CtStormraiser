

local fs = require 'coro-fs'
local path = require 'path'
local timer = require 'timer'
local base64 = require 'base64'

local vips = require 'vips'
local pesc = require 'util'.patternEscape
local slaxml = require 'slaxdom'

local defer = require 'renderer/defer'


--=============================================--


local LAYOUT_DIR = 'layouts'
local TEMP_DIR = path.join(LAYOUT_DIR, '_tmp')
local DEBUG = false


--=============================================--

-- TODO put all render files into temp folder


local Renderer = {}

function Renderer.setup()
    if Renderer.doneSetup then return end
    Renderer.doneSetup = true

    vips.cache_set_max(0)
    vips.leak_set(DEBUG)

    Renderer._preloadFonts()
end

-- layout: e.g. 'MainArea'
function Renderer.render(layout, vars, outFile, tmpdir)
    Renderer.setup()

    tmpdir = tmpdir or (TEMP_DIR..(os.clock()*1000))
    fs.mkdirp(tmpdir)
    local fn = path.join(LAYOUT_DIR, path.basename(outFile)..'.svg')

    local ok, err = xpcall(function()
        local svg = assert(fs.readFile(path.join(LAYOUT_DIR, layout..'.svg')))
        local dom = slaxml:dom(svg, { stripWhitespace = true })

        vars._rootSettings = { workdir = tmpdir }
        Renderer._parse(dom, vars)
        svg = slaxml:xml(dom)

        -- svg needs to be a file to have paths be properly referenced
        fs.writeFile(fn, svg)
        vips.Image.new_from_file(fn):write_to_file(outFile)
    end, debug.traceback)

    -- make sure vips closes all file handles it still has
    collectgarbage()
    collectgarbage()

    while not fs.rmrf(tmpdir) and fs.access(tmpdir) do
        if DEBUG then print('waiting for resource: '..tmpdir) end
        timer.sleep(1000)
    end
    fs.unlink(fn)

    if not ok then error(err) end
end

function Renderer.imageText(name, value)
    Renderer.setup()

    return defer.SvgTextGen.new(name, value)
end

function Renderer.imageFromPath(imgPath)
    Renderer.setup()

    return defer.FromImageFile.new(imgPath)
end

function Renderer._preloadFonts()
    local fonts = {'LTMuseum-Reg.ttf','LTMuseum-Bold.ttf','LTMuseum-Ital.ttf'}
    for _,fn in ipairs(fonts) do
        vips.Image.text(".", {width=4, font="LT Museum", fontfile=path.join(LAYOUT_DIR, 'fonts', fn)})
    end
end

local ops = {}
local search
function Renderer._parse(dom, vars)
    search(dom, function(node)
        if node.attr and node.attr.id then
            local opName, opArg = node.attr.id:match('{{([^$=]+)=([^}]+)}}')
            if opName then
                local args = {}
                for arg in opArg:gmatch('[^,]+') do
                    args[#args+1] = arg
                end
                if ops[opName] then
                    ops[opName](args, node, vars)
                end
            end
        end
    end)
end


--=============================================--


search = function(node, cb)
    if not node.kids then return end
    for i,ch in ipairs(node.kids) do
        cb(ch)
        if node.kids[i].kids then
            search(node.kids[i], cb)
        end
    end
end

-- attrs is {{'key1', 'val1'}, {'key2', 'val2'}, ...}
local function makeElement(name, attrs)
    local elem = {type = 'element', name = name, kids = {}, el = {}}
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


--=============================================--


function ops.REI(args, node, varstb)
    local varName = table.remove(args, 1)
    for i in ipairs(args) do args[table.remove(args, i):lower()] = true end

    local im = varstb[varName]
    local rx, ry = tonumber(node.attr.x or 0), tonumber(node.attr.y or 0)
    local rw, rh = tonumber(node.attr.width), tonumber(node.attr.height)
    if type(im) == 'table' and im.vimage then
        local x, y = rx, ry
        local w, h = tonumber(im:width()), tonumber(im:height())

        local fac = math.min(args.limitw and rw/w or 1, args.limith and rh/h or 1)
        if fac < 0.99 then
            im = im:resize(fac)
            w, h = tonumber(im:width()), tonumber(im:height())
        end

        if args.center then
            x, y = getCenteredOffset(rx, ry, rw, rh, w, h)
        end

        slaxml:replace(node, makeElement('image', {
            {'x', tostring(x)},
            {'y', tostring(y)},
            {'width', tostring(w)},
            {'height', tostring(h)},
            {'href', 'data:image/png;base64,'..base64.encode(tostring(im:write_to_buffer(".png")))}
        }))
    elseif type(im) == 'table' and im._processable then
        local outFile = path.join(varstb._rootSettings.workdir, im:getUniqueName()..'.png')
        local png = im:generate(outFile, args.limitw and rw or nil, args.limith and rh or nil)

        local x, y = rx, ry
        local w, h = tonumber(png:width()), tonumber(png:height())
        if args.center then
            x, y = getCenteredOffset(rx, ry, rw, rh, w, h)
        end

        slaxml:replace(node, makeElement('image', {
            {'x', tostring(x)},
            {'y', tostring(y)},
            {'width', tostring(w)},
            {'height', tostring(h)},
            {'href', path.relative(LAYOUT_DIR, outFile):gsub('\\','/')}
        }))
    end
end

function ops.REP(args, node, varstb)
    local filename, config, varsArray = args[1], varstb[args[2]], varstb[args[3]]
    if not config or not varsArray then
        error("Misconfigured REP: missing _CONFIGVAR_ or _VARSTABLEVAR_")
    end

    local _svg = assert(fs.readFile(path.join(LAYOUT_DIR, filename)))
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
        vars._rootSettings = {}
        for k,v in pairs(varstb._rootSettings) do
            vars._rootSettings[k] = v
        end

        Renderer._parse(newDom, vars)
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


--=============================================--


return Renderer
