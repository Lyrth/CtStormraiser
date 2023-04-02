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
    ---@type string
    local s = process.env.CtLogins
    assert(s and #s > 0, "CtLogins env var not specified.")
    local i = 0
    for d, a, b, u in s:gmatch('(%S+)[^\n%S]+(%S+)[^\n%S]+(%S+)[^\n%S]+(%S+)[^\n%S]-\n') do
        acs[i] = {a = a, b = b, d = d, u = u}
        i = i + 1
    end
end

---@type CtLib[]
local logins = {}

local function setupAcc(n)
    assert(acs[n], "n beyond number of available accounts.")
    local acc = CtLib.login(acs[n].a, acs[n].b)
    acc:updateDisplayName(acs[n].u)
    acc:setPlayerAllData {
        Setup = {
            Custo = {},
            ClassID = 'CL03',
            IconID = 'PI011',
            FanionID = 'FA004',
            TitleId = 'PT064',
            WallID = 'WP003',
        }
    }
    return acc
end

---@return CtLib
function logins.getAcc(n)
    if not n then n = 1 end
    assert(type(n) == 'number' and n >= 0 and n % 1 == 0, "n must be a valid positive integer")
    if not logins[n] then
        logins[n] = setupAcc(n)
    end
    return logins[n]
end

---@return CtLib
function logins.getMain()
    return logins.getAcc(0)
end

return logins
