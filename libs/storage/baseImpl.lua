-- base db impl

-- DB note: data-type keys (func,table,userdata,thread,nil,etc) are not allowed
-- key=1 and key="1" will yield the same value
-- key=true and key="true" same as above
--
-- NIL: nil value that should not get removed - mostly only used for human-readable data. it just makes get return nil anyway,
-- and each/values still wont give you a nil value
--
-- open(dbName)
-- from(tb, nestedObjects)      -- make tb a db, optionally making nested tables dbs as well
-- --- note: unspecified key (key==nil) on get/each/keys/vals will make thing return/use itself
-- get(key, default?)   -- get key from table
-- get{key1,key2,...,default? = default}   -- nested
-- set(key, value, isObject)    -- isObject (def false): true to attach db metamethods to it, false otherwise
-- set{key1,key2,...,value = value, isObject = false}   -- key1,key2,... will become plain tables if not exist
-- del(key) 
-- del{key1,key2,...}   -- will also return removed value, if any
-- each(key) -> k,v
--  ? find(fun(k,v):boolean, recurseObjects)
--  ? hash()    -- hash table contents
--  ? debug{key1,key2,...}   -- print the nesting flow (good for detecting nil)

-- TODO: links?

-- A:B(C) -> A.B(A, C) 

---@class UnderlyingTableKey : table
---@class ConfigTableKey : table
---@class ParentTableKey : table

---@class DbStore
---@field _meta table
---@field _utKey UnderlyingTableKey
---@field _confKey ConfigTableKey
local db = {}

function db:extend()
    local new = setmetatable({}, {__index = self, __call = function(t, ...) return t.new(t, ...) end})
    new._meta = {__index = new}
    return new
end

local meta = {__index = db}

-- Private key for the db's underlying table
---@type UnderlyingTableKey
local _utKey = ({})
---@type ConfigTableKey
local _confKey = ({})

db._utKey = _utKey
db._confKey = _confKey
db._pKey = _pKey


local function isValidKey(k)
    return type(k) == 'string' or tonumber(k) ~= nil or type(k) == 'boolean'
end

local function checkKeyType(k)
    return isValidKey(k) or error("Invalid key type: "..type(k))
end

-- discards noncompliant keys, nonserializable values, removes metatables, does not keep cyclic references
---@generic T table|any
---@param orig T
---@return T
local function tcopym(orig, mt, _copies)
    mt = mt or meta
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
                        t[orig_key] = tcopym(orig_value, mt, _copies)
                    end
                end
            end
            return setmetatable({[_utKey] = t}, mt)
        end
    else
        return type(orig) == 'cdata' and tonumber(orig) or orig
    end
end


---@param pass boolean do not shallow clone table (also wont check valid keys)
---@return table
function db:from(tb, pass)
    if not self._meta then error("Unimplemented") end
    if pass then
        return setmetatable({[_utKey] = tb, [_confKey] = {}}, self._meta)
    end

    local t = {}
    for k, v in next, tb, nil do
        if isValidKey(k) then
            t[k] = v
        end
    end
    return self:from(t, true)
end

---@return DbStore
function db:open() error("Unimplemented") end

--- get(key, default?)   -- get key from table
--- get{key1,key2,...,default? = default}   -- nested: when nontable encountered in the middle, returns default
function db:get() error("Unimplemented") end


function db:set() error("Unimplemented") end
function db:del() error("Unimplemented") end
function db:each() error("Unimplemented") end
function db:keys() error("Unimplemented") end
function db:vals() error("Unimplemented") end

function db._setRoot(rootPath) end
function db._runBackground() end

return db
