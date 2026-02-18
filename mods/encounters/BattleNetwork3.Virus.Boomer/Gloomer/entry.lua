local shared_character_init = require("../Boomer/character.lua")

function character_init(character)
    local character_info = {
        name = "Gloomer",
        hp = 140,
        damage = 60,
        palette = Resources.load_texture("palette.png"),
        frames_between_actions = 78,
        boomer_speed = 7,
        move_speed = 50,
        panelgrabs = 1,
    }

    shared_character_init(character, character_info)
end
