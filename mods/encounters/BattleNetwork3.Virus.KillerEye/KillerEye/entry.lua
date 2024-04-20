local shared_character_init = require("./character.lua")
local character_id = "louise_enemy_"
function character_init(character)
    local character_info = {
        name = "KillerEye",
        hp = 100,
        damage = 50,
        palette = Resources.load_texture("V1.png"),
        height = 80,
    }
    if character:rank() == Rank.SP then
        character_info.damage = 200
        character_info.palette = Resources.load_texture("SP.png")
        character_info.hp = 230
    elseif character:rank() == Rank.Rare1 then
        character_info.damage = 120
        character_info.palette = Resources.load_texture("Rare1.png")
        character_info.hp = 170
    elseif character:rank() == Rank.Rare2 then
        character_info.damage = 250
        character_info.palette = Resources.load_texture("Rare2.png")
        character_info.hp = 250
    end
    shared_character_init(character, character_info)
end
