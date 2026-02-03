local shared_character_init = require("../shared/entry.lua")
local texture = Resources.load_texture("Metrodo.png")

function character_init(character)
    character:set_name("Metrod")
    character:set_texture(texture)

    character._accuracy_chance = 10
    character._cooldown = 14
    character._minimum_meteors = 4
    character._maximum_meteors = 6
    character._damage = 120
    character._health = 250
    character._idle_max = 35

    shared_character_init(character)
end
