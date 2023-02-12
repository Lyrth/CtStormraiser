-- JSON db impl

local base64 = require 'base64'
local timer = require 'timer'
local json = require 'json'
local path = require 'path'
local fs = require 'coro-fs'

local util = require 'util'

local base = require './baseImpl'

local jassert, tbHash = util.jsonAssert, util.tbHash



local UPDATE_INTERV = 5*1000        -- 5 seconds after last edit - write changes
local HANDLE_TIMEOUT = 12*60*1000   -- 12 minutes - close file when unused (get/set)


---@class JsonDbStore : DbStore
local db = base:extend()

local _utKey, _confKey, _pKey  = db._utKey, db._confKey, db._pKey
local _confStrKey = '$$\1dbconfig\1$$'


--=============================================--


-- <path, {fd, lastAccess}>
local openFiles = {}

local function openFile(f, readOnly)
    f = path.resolve(f)
    if fs.access(f) then
        if assert(fs.stat(f)).type == 'file' then
            if not fs.access(f, readOnly and 'r' or 'rw') then
                error("'"..f.."': missing permissions.")
            end
            return assert(fs.open(f, readOnly and 'r' or 'r+')), f
        else
            error("'"..f.."': not a file.")
        end
    else
        if readOnly then error("'"..f.."': does not exist.") end
        assert(fs.mkdirp(path.dirname(f)))
        return assert(fs.open(f, 'wx+')), f
    end
end

local function getFile(pathName, dbName, readOnly)
    return openFile(path.join(pathName, dbName..'.json'), readOnly)
end


local function fetchContent(fd)
    local j = assert(fs.read(fd, nil, 0))     -- always read from start
    return jassert(json.decode(j and #j > 0 and j or '{}'))
end

local function _jsonWarn(reason, v, s, err)
    print(("Warning: JSON encoding exception: [%s]: %s: %s"):format(tostring(v), reason, err))
    return ''
end

local ftruncateSync, fsyncSync = require'fs'.ftruncateSync, require'fs'.fsyncSync
local function writeContent(fd, v, conf)
    local j = json.encode(v or {}, {indent = true, exception = _jsonWarn})
    ftruncateSync(fd)
    assert(fs.write(fd, j, 0))
    fsyncSync(fd)
end


local function checkUpdate(t, conf)
    local newHash, contHash
    local s, v
    if not conf.dirty or not conf.fd then goto ok end

    newHash = util.tbHash(t[_utKey])
    if newHash == conf.hash then goto ok end

    s, v = pcall(fetchContent, conf.fd)
    if not s then
        fs.close(conf.fd)
        conf.fd = nil
        conf.path = nil
        conf.wTimer = nil
        error(v)
    end

    contHash = util.tbHash(v)
    if contHash == conf.hash then goto ok end

    if conf.readOnly then
        t = t:from(v, true)
        conf.hash = contHash
        t[_confKey] = conf
    else
        s, v = pcall(writeContent, conf.fd, t[_utKey])
        if not s then
            fs.close(conf.fd)
            conf.fd = nil
            conf.path = nil
            conf.wTimer = nil
            error(v)
        end
        conf.hash = newHash
    end

    ::ok::
    conf.dirty = false
    conf.wTimer = nil
end

local function queueUpdate(t, conf)
    if conf.wTimer then timer.clearTimeout(conf.wTimer) end
    conf.wTimer = timer.setTimeout(UPDATE_INTERV, coroutine.wrap(checkUpdate), t, conf)
end

local function checkIsDb(t)
    if not t[_utKey] then error("Table is not a db.", 1) end
end


--=============================================--

--- NOTE: when dealing with nested tables, use set/get instead of raw indexing
---@return JsonDbStore
function db:open(dbName, readOnly)
    -- make file here etc
    local fd, fpath = getFile(self.rootPath, dbName, readOnly)
    local s, v = pcall(fetchContent, fd)
    if not s then
        fs.close(fd)
        error(v)
    end

    local t = self:from(v, true)

    local conf = t[_confKey]
    conf.fd = fd
    conf.path = fpath
    conf.readOnly = readOnly
    if readOnly then
        conf.hash = util.tbHash(v)
    else
        -- force a write next cycle
        conf.dirty = true
        conf.hash = ''
        queueUpdate(t, conf)
    end

    return t
end

function db:get(k, def)
    checkIsDb(self)
    if type(k) == 'table' then
        def = k.default
    else
        k = {k}
    end

    local t = self[_utKey]
    local v = t
    for i = 1, #k do
        if type(v) ~= 'table' then
            if v ~= nil then
                print(("Warning: nesting into '%s' failed: is of type %s. Returning default"):format(table.concat(k, '.', 1, i-1), type(v)))
            end
            return def
        end
        v = v[k[i]]
    end

    if v == nil then
        return def
    else
        return v
    end
end

-- Creates tables it passes by
-- returns old value
function db:set(k, value)
    checkIsDb(self)
    if type(k) == 'table' then
        value = k.value
    else
        k = {k}
    end
    if #k < 1 then return end

    local t = self[_utKey]
    local v = t
    for i = 1, #k - 1 do
        if type(v) ~= 'table' then
            print(("Warning: nesting into '%s' failed: is of type %s. Set did nothing"):format(table.concat(k, '.', 1, i-1), type(v)))
            return nil
        end
        if i == #k then break end
        if v[k[i]] == nil then v[k[i]] = {} end
        v = v[k[i]]
    end

    if type(v) ~= 'table' then
        print(("Warning: nesting into '%s' failed: is of type %s. Set did nothing"):format(table.concat(k, '.', 1, #k-1), type(v)))
        return nil
    end
    local oldValue = v[k[#k]]
    v[k[#k]] = value
    self[_confKey].dirty = true
    queueUpdate(self, self[_confKey])

    return oldValue
end

function db:del(k)
    return self:set(k, nil)
end

function db:each()
    return pairs(self[_utKey])
end


--=============================================--


function db._setRoot(rootPath)
    db.rootPath = type(rootPath) == 'string' and rootPath or error("rootPath is not a string")
end


-- TODO: update from file to db
local hasRan = false
function db._runBackground()
    -- if not hasRan then
    --     timer.setInterval(UPDATE_INTERV, function()
    --         -- TODO do this: update on dirty
    --     end)
    --     hasRan = true
    -- end
end


-- TODO: function to freeze transactions - to update files while running
-- (close all open files and probably put things in queue)

return db
