local shared_character_init = require("../Boomer/character.lua")
function character_init(character)
    local character_info = {
        name = "Doomer",
        hp = 180,
        damage = 90,
        palette = Resources.load_texture("palette.png"),
        height = 44,
        frames_between_actions = 78,
        boomer_speed = 5,
        move_speed = 30,
        panelgrabs = 2,
    }

    shared_character_init(character, character_info)
end
