local shared_package_init = require("../shared/entry.lua")
function character_init(character)
    local character_info = {
        name = "Bladia4",
        hp = 300,
        attack = 160,
        height = 70,
        palette = "bladia.png"
    }
    shared_package_init(character, character_info)
end
