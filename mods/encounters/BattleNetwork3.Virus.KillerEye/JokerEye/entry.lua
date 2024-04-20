local shared_character_init = require("../KillerEye/character.lua")
local character_id = "louise_enemy_"
function character_init(character)
    local character_info = {
        name = "JokerEye",
        hp = 190,
        damage = 150,
        palette = Resources.load_texture("palette.png"),
        height = 80,
    }

    shared_character_init(character, character_info)
end
