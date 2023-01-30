-- Externalize embedded images (since libvips can support external images, make svgs cleaner)

local fs = require 'fs'
local base64 = require 'base64'

fs.mkdirSync('res')
local found = false
for _, name in ipairs(fs.readdirSync('.')) do
    if not name:match('%.svg$') then goto continue end

    local svg = assert(fs.readFileSync(name))
    local replacements = {}

    for filename, toReplace, data in svg:gmatch('data%-name="([^"]+)"[^>]+xlink:href="(data:image/png;base64,([^"]+))"') do
        found = true
        local newFilename = 'res/'..filename
        fs.writeFileSync(newFilename, base64.decode(data))
        replacements[#replacements+1] = {toReplace:gsub('+','%%%+'), newFilename}
    end
    if not found then goto continue end

    for _, repl in ipairs(replacements) do
        svg = svg:gsub(repl[1], repl[2])
    end

    fs.writeFileSync(name, svg)

    ::continue::
end

if not found then print "svgs seem to be converted already." end

print "Done."
