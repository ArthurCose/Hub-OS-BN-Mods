local shared_package_init = require("../shared/entry.lua")
function character_init(character)
    local character_info = {
        name = "Bladia5",
        hp = 340,
        attack = 200,
        height = 70,
        palette = "bladia.png"
    }
    shared_package_init(character, character_info)
end
