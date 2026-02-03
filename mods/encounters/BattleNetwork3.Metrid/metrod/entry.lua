local shared_character_init = require("../shared/entry.lua")
local texture = Resources.load_texture("Metrod.png")

function character_init(character)
    character:set_name("Metrod")
    character:set_texture(texture)

    character._accuracy_chance = 15
    character._cooldown = 12
    character._minimum_meteors = 8
    character._maximum_meteors = 8
    character._damage = 80
    character._health = 200
    character._idle_max = 40

    shared_character_init(character)
end
