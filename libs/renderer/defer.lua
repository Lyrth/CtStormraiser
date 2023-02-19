
-- intermediate thingy for REI operations to defer processing

local fs = require 'coro-fs'
local path = require 'path'

local sha2 = require 'sha2'
local vips = require 'vips'
local slaxml = require 'slaxdom'


local LAYOUT_DIR = 'layouts'



local FromImageFile = {}
FromImageFile._processable = true
FromImageFile.__index = FromImageFile

function FromImageFile.new(fromPath)
    if not fs.access(fromPath, 'r') then error('cannot access file '..fromPath) end
    return setmetatable({path = fromPath}, FromImageFile)
end

function FromImageFile:getUniqueName()
    return path.basename(self.path, path.extname(self.path))..'new'
end

function FromImageFile:generate(outPath, maxWidth, maxHeight)
    local im = vips.Image.new_from_file(self.path)

    local fac = math.min(maxWidth and (maxWidth/im:width()) or 1, maxHeight and (maxHeight/im:height()) or 1, 1)
    if fac < 0.9999 then im = im:resize(fac) end

    im:write_to_file(outPath)
    return im
end



local SvgTextGen = {}
SvgTextGen._processable = true
SvgTextGen.__index = SvgTextGen

local svgCache = {}

---@return integer, integer, integer
local function col2Rgb(str)
    return table.unpack(vips.Image.text(('<span foreground="%s">█</span>'):format(str), {rgba=true}):getpoint(2,2), 1, 3)
end

-- extracts info from the first text tag it sees
function SvgTextGen.new(name, value)
    return setmetatable({name = name, text = tostring(value)}, SvgTextGen)
end

function SvgTextGen:getUniqueName()
    return ('%s-%s'):format(self.name, sha2.bin2base64(sha2.hex2bin(sha2.blake3(self.text))):gsub('/','_'):gsub('=',''))
end

function SvgTextGen:generate(outPath, maxWidth, maxHeight)
    if not svgCache[self.name] then
        local str = assert(fs.readFile(path.join(LAYOUT_DIR, 'Text'..self.name..'.svg')))
        local svg = slaxml:dom(str, { stripWhitespace = true })
        local txt = slaxml:find(svg, { name = 'text' }) or error("No text node in svg file "..self.name..".svg")
        local att = txt.attr
        local markup = '<span font_family="%s" font_size="%.6fpt" font_style="%s" font_weight="%s" color="%s" alpha="%d%%" text_transform="%s">'
        local tag = markup:format(
            att['font-family'],
            tonumber(att['font-size'] or '12'),
            att['font-style'] or 'normal',
            att['font-weight'] or 'normal',
            att['fill'] or 'white',
            (att['fill-opacity'] or 1)*100,
            att['text-transform'] or 'none'
        )

        svgCache[self.name] = {tag = tag, stroke = att.stroke and {color = {col2Rgb(att.stroke)}, width = tonumber(att['stroke-width']) or 1}}
    end

    local text = vips.Image.text(svgCache[self.name].tag..self.text..'</span>', {rgba = true, dpi = 75})

    local fac = math.min(maxWidth and (maxWidth/text:width()) or 1, maxHeight and (maxHeight/text:height()) or 1, 1)
    if fac < 0.9999 then
        text = text:resize(fac)
        -- note: the border wasn't counted lol
    end

    if not svgCache[self.name].stroke then
        text:write_to_file(outPath)
        return text
    end

    local w, col = svgCache[self.name].stroke.width, svgCache[self.name].stroke.color
    text = text:embed(w, w, text:width() + 2*w, text:height() + 2*w)

    local mask = vips.Image.gaussmat(w/2, 0.1, {separable = true}) * 4
    local wide = text:extract_band(3)
    wide = wide:less(0x0C)
        :ifthenelse(0, wide)
        :convsep(mask)
        :cast('uchar')

    local iout = wide:new_from_image(col)
        :bandjoin(wide)
        :copy{interpretation = 'srgb'}
        :composite(text, 'over')
    iout:write_to_file(outPath)
    return iout
end


return {
    SvgTextGen = SvgTextGen,
    FromImageFile = FromImageFile,
}
