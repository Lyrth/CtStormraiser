
local sha2 = require 'sha2'

---@generic T any
---@param v T|nil
---@return T
local function jsonAssert(v,p,m)
    return (m and error(("JSON error: %d: %s"):format(p, m))) or v
end

local function parseServerDate(str)
    local year,month,day,hour,min,sec,ms = str:match '^(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)%.(%d+)Z'
    local dtz = (os.time()-os.time(os.date("!*t")))

    return dtz + os.time {
        sec = sec,
        min = min,
        isdst = false,
        hour = hour,
        day = day,
        month = month,
        year = year
    }
end


-- return: sha256 base64
local next, type, tostring, tsort = next, type, tostring, table.sort
local b3, h2b = sha2.blake3, sha2.hex2bin

--- NOTE: Returns a binary string; will discard non-string/number/boolean keys, discard non-string/number/boolean/table and cyclic reference values
local function tbHash(tb,_,seen)
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
            v = tbHash(v, nil, seen)
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

local function cleanTable(tb,_,seen)
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
            v = cleanTable(v, nil, seen)
        elseif tv ~= 'string' then
            tb[k] = nil
        end
    end
end

return {
    parseServerDate = parseServerDate,
    jsonAssert = jsonAssert,
    tbHash = tbHash,
    cleanTable = cleanTable,
}
