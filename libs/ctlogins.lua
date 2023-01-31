--[[=============================================--
-- ctlogins.lua
-- Login getters
--
--
-- SPDX-License-Identifier: GPL-3.0-only
-- Author: Lyrthras
--=============================================]]--

local process = process or require 'process'.globalProcess()

local CtLib = require 'CtLib'

local acs = {}
do
    local s = process.env.CtLogins
    assert(s and #s > 0, "CtLogins env var not specified.")
    local i = 0
    for d, a, b in s:gmatch('(%S+)%s+(%S+)%s+(%S+)%s+') do
        acs[i] = {a = a, b = b, d = d}
        i = i + 1
    end
end

---@type CtLib[]
local logins = {}

---@return CtLib
function logins.getMain()
    logins[0] = logins[0] or CtLib.login(acs[0].a, acs[0].b)
    return logins[0]
end


return logins
