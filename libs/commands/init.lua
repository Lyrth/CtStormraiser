
---@class SlashCommandDef : SlashCommand
---@field handle fun(intr: Interaction)

-- File names for each command
local commands = {
    'ping',
    'shop',
    'test',
    'get_playfab_id',
    'status_channel',
}


---@type SlashCommand[]
local slashCommands = {}

---@type table<string, fun(intr: Interaction)>
local handlers = {}

for _, filename  in ipairs(commands) do
    ---@type boolean, SlashCommandDef
    local ok, command = pcall(require, './'..filename)
    if ok then
        handlers[command.name] = command.handle
        command.handle = nil

        slashCommands[#slashCommands+1] = command
    else
        print("WARNING: command filename '"..filename..".lua' not found.\n", command)
    end
end

return {
    slashCommands = slashCommands,
    handlers = handlers,
}
