local shared_package_init = require("../shared/entry.lua")
function character_init(character)
    local character_info = {
        name = "Bladia2",
        hp = 230,
        attack = 80,
        height = 70,
        palette = "bladia.png"
    }
    shared_package_init(character, character_info)
end
