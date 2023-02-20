--[[=============================================--
-- util.lua
-- Some random utilities used for the bot
--
--
-- SPDX-License-Identifier: GPL-3.0-only
-- Author: Lyrthras
--=============================================]]--

local sha2 = require 'sha2'

local util = {}

---@generic T any
---@param v T|nil
---@return T
function util.jsonAssert(v,p,m)
    return (m and error(("JSON error: %d: %s"):format(p, m))) or v
end

function util.getTzOffset()
    return os.time() - os.time(os.date("!*t"))
end

function util.parseServerDate(str)
    local year,month,day,hour,min,sec,ms = str:match '^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)%.(%d+)Z'

    return util.getTzOffset() + os.time {
        sec = sec,
        min = min,
        isdst = false,
        hour = hour,
        day = day,
        month = month,
        year = year
    }
end

function util.locresFmt(text)
    return text
        :gsub('<img id="RichText%.BulletPoint"/>', ' ‣ ')
        :gsub('<b>([^<]*)</>', '<b>%1</b>')
end

---@param client Client
function util.sendErrorToOwner(client, err)
    client:getUser('368727799189733376'):send(("An error has occured! ```\n%s\n```"):format(err:sub(1900)))
end

function util.patternEscape(str)
    return (str:gsub("([^%w])", "%%%1"))
end



-- return: sha256 base64
local next, type, tostring, tsort = next, type, tostring, table.sort
local b3, h2b = sha2.blake3, sha2.hex2bin

--- NOTE: Returns a binary string; will discard non-string/number/boolean keys, discard non-string/number/boolean/table and cyclic reference values
function util.tbHash(tb,_,seen)
    seen = seen or {}
    local x = {}
    for k, v in next, tb, nil do
        local tk, tv = type(k), type(v)
        if tk == 'number' or tk == 'boolean' then
            k = tostring(k)
        elseif tk ~= 'string' then
            goto continue
        end
        if tv == 'number' or tv == 'boolean' then
            v = tostring(v)
        elseif tv == 'table' and not seen[v] then
            seen[v] = true
            v = util.tbHash(v, nil, seen)
        elseif tv ~= 'string' then
            goto continue
        end
        x[#x+1] = k..'\1'..v
        ::continue::
    end
    tsort(x)
    local hash = b3()
    for i = 1, #x do
        hash(x[i])
    end
    return h2b(hash())
end
function util.cleanTable(tb,_,seen)
    seen = seen or {}
    for k, v in next, tb, nil do
        local tk, tv = type(k), type(v)
        if tk == 'number' or tk == 'boolean' then
            tb[k] = nil
            k = tostring(k)
            tb[k] = v
        elseif tk ~= 'string' then
            tb[k] = nil
        end
        if tv == 'number' or tv == 'boolean' then
            tb[k] = tostring(v)
        elseif tv == 'table' and not seen[v] then
            seen[v] = true
            v = util.cleanTable(v, nil, seen)
        elseif tv ~= 'string' then
            tb[k] = nil
        end
    end
end

local function isValidKey(k)
    return type(k) == 'string' or tonumber(k) ~= nil or type(k) == 'boolean'
end

-- discards noncompliant keys, nonserializable values, removes metatables, does not keep cyclic references
---@generic T table|any
---@param orig T
---@return T
function util.tcopym(orig, _, _copies)
    _copies = _copies or {}
    if type(orig) == 'table' then
        if _copies[orig] then
            -- discard
            return nil
        else
            _copies[orig] = true
            local t = {}
            for orig_key, orig_value in next, orig, nil do
                if isValidKey(orig_key) then
                    if (type(orig_value) == 'string' or
                        type(orig_value) == 'number' or
                        type(orig_value) == 'boolean') then
                        t[orig_key] = orig_value
                    elseif (
                        type(orig_value) == 'table' or
                        type(orig_value) == 'cdata') then
                        t[orig_key] = util.tcopym(orig_value, _, _copies)
                    end
                end
            end
            return t
        end
    else
        return type(orig) == 'cdata' and tonumber(orig) or orig
    end
end

function util.contains(t, v)
    for i = 1, #t do
        if t[i] == v then return true end
    end
    return false
end

util.b64decode = sha2.base642bin
util.b64encode = sha2.bin2base64

return util
