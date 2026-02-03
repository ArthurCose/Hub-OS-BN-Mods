local shared_character_init = require("../shared/entry.lua")

local texture_v1 = Resources.load_texture("Metrid.png")
local texture_nm = Resources.load_texture("MetridNM.png")
local texture_omega = Resources.load_texture("Omega.png")

function character_init(character)
    character:set_name("Metrid")
    local rank = character:rank()

    if rank == Rank.Omega then
        character._health = 300
        character._damage = 40
        character._cooldown = 10
        character._minimum_meteors = 4
        character._maximum_meteors = 8
        character._accuracy_chance = 20
        character._idle_max = 35
        character:set_texture(texture_omega)
    elseif rank == Rank.NM then
        character._health = 500
        character._damage = 300
        character._cooldown = 8
        character._minimum_meteors = 4
        character._maximum_meteors = 8
        character._accuracy_chance = 33
        character._idle_max = 30
        character:set_texture(texture_nm)
    else
        character._cooldown = 16
        character._minimum_meteors = 4
        character._maximum_meteors = 8
        character._damage = 40
        character._health = 150
        character._idle_max = 40
        character._accuracy_chance = 5
        character:set_texture(texture_v1)
    end

    shared_character_init(character)
end
