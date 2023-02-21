return {
    name = "Lyrth/StormraiserBot",
    version = "1.3.1",
    description = "Stormraiser bot for the official Century: Age of Ashes server.",
    license = "GNU General Public License v3.0",
    author = { name = "Lyrthras", email = "me[at]lyr.pw" },
    homepage = "https://github.com/Lyrth/StormraiserBot",
    private = true,
    dependencies = {
        "creationix/coro-fs",
        "https://github.com/Bilal2453/discordia-components",
        "https://github.com/Bilal2453/discordia-interactions",
        "https://github.com/Bilal2453/lit-vips",
        "https://github.com/wbx/Discordia",
        "https://github.com/wbx/discordia-llslash",
        "https://github.com/wbx/lit-PlayFabClientSdk",
        "ssh://git@github.com/wbx/CtLib.git",   -- private dependency.
    },
    files = {
        "**.lua",
        "!test*",
        "!_private",
        "!_workfiles"
    }
}
