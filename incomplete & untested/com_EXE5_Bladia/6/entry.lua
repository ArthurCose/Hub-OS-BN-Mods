local shared_package_init = require("../shared/entry.lua")
function character_init(character)
    local character_info = {
        name = "Bladia6",
        hp = 400,
        attack = 250,
        height = 70,
        palette = "bladia.png"
    }
    shared_package_init(character, character_info)
end
