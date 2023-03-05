--[[=============================================--
-- shop.lua
-- Century shop command
--
--
-- SPDX-License-Identifier: GPL-3.0-only
-- Author: Lyrthras
--=============================================]]--

---@type SlashCommandDef
local cmd = {
    name = "get_playfab_id",
    description = "Get the Playfab ID from a username.",
    options = {
        {
            name = "username",
            description = "Player username, e.g. SomeUser#A1B2C",
            required = true,
            type =  3,
        }
    },
    dm_permission = false,
}


local logins = require 'ctlogins'

function cmd.handle(intr)
    local opt1 = intr.data.options[1]
    assert(opt1.name == 'username', "Invalid options form received: name")
    local uname = tostring(opt1.value)

    local id, err = logins.getMain():getPlayfabIdFromName(uname)
    if not id then
        if type(err) == 'string' and err:find('AccountNotFound') then
            local msg = "User not found!"
            if uname:find("^%s") or uname:find("%s$") then
                msg = msg .. " (Warning: leading/trailing space(s) detected.)"
            end
            intr:reply(msg)
            return
        end
        error(err)
    end

    intr:reply(("`%s` - PlayFab ID: `%s`"):format(uname:gsub('`','<tilde>'), id))
end


return cmd
