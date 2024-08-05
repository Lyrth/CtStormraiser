
---@type SlashCommandDef
local cmd = {
    name = "profile",
    description = "e",
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
local Date = require 'discordia'.Date

local classes = {
    CL01 = 'Phantom',
    CL02 = 'Windguard',
    CL03 = 'Marauder',
    CL04 = 'Stormraiser',
    CL05 = 'Thornweaver',
    CL06 = 'Rimeblood',
}

function cmd.handle(intr)
    local opt1 = intr.data.options[1]
    assert(opt1.name == 'username', "Invalid options form received: name")
    local uname = tostring(opt1.value)

    -- intr:replyDeferred(true)

    local ctlib = logins.getMain()
    local info, err = ctlib:getPlayfabInfoFromName(uname)
    local id = info and info.PlayFabId
    if not info then
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

    local profile, err = ctlib:getProfile(id)
    if not profile then
        if type(err) == 'string' then
            intr:reply("Error occured!\n"..err)
        end
        error("ERROR AT profile: " .. tostring(err))
    end

    local classTimes = ""

    table.sort(profile.Stats.Class, function(a, b)
        return a.Time > b.Time
    end)

    for _,v in ipairs(profile.Stats.Class) do
        classTimes = classTimes .. ("- %s:  %dh %dm %ds\n"):format(classes[v.ID] or '?', math.floor(v.Time / 3600), math.floor((v.Time % 3600) / 60), v.Time % 60)
    end

    local createTime = Date.fromISO(info.Created):toSeconds()

    intr:reply(([[
`%s` - PlayFab ID: `%s`

Display Name:  %s
Level:  %d
Rank (Teams/SoloDuo):  %d / %d
K/A/D - Ratio:  %d / %d / %d  -  %0.2f
W/D/L - Ratio:  %d / %d / %d  -  %0.2f
Disconnect count:  %d
Creation date:  <t:%d:F>, <t:%d:R>
Class times:
%s
    ]]):format(
        uname:gsub('`','<tilde>'), id,
        profile.Name:gsub('([`*])','\\%1'),
        profile.Stats.Level,
        profile.Rank, profile.RankSoloDuo,
        profile.Stats.TotalFrag, profile.Stats.TotalAssist, profile.Stats.TotalDeath, profile.Stats.TotalFrag/math.max(profile.Stats.TotalDeath,1),
        profile.Stats.WonMatchCount, profile.Stats.DrawMatchCount, profile.Stats.LostMatchCount, profile.Stats.WonMatchCount/math.max(profile.Stats.LostMatchCount,1),
        profile.Stats.ExitCount,
        createTime, createTime,
        classTimes
    ))
end


return cmd
