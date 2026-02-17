local shared_character_init = require("../shared/entry.lua")

local texture_v1 = Resources.load_texture("Metrid.png")
local texture_nm = Resources.load_texture("MetridNM.png")
local texture_omega = Resources.load_texture("Omega.png")
local texture_metrod = Resources.load_texture("Metrod.png")
local texture_metrodo = Resources.load_texture("Metrodo.png")

---@param character Metrid
function character_init(character)
    character:set_name("Metrid")
    local rank = character:rank()

    if rank == Rank.V2 then
        character._accuracy_chance = 15
        character._meteor_cooldown = 12
        character._minimum_meteors = 8
        character._maximum_meteors = 8
        character._attack = 80
        character._health = 200
        character._idle_max = 40

        character:set_name("Metrod")
        -- character:hide_rank()
        character:set_texture(texture_metrod)
    elseif rank == Rank.V3 then
        character._accuracy_chance = 10
        character._meteor_cooldown = 14
        character._minimum_meteors = 4
        character._maximum_meteors = 6
        character._attack = 120
        character._health = 250
        character._idle_max = 35

        character:set_name("Metrodo")
        -- character:hide_rank()
        character:set_texture(texture_metrodo)
    elseif rank == Rank.Omega then
        character._health = 300
        character._attack = 40
        character._meteor_cooldown = 10
        character._minimum_meteors = 4
        character._maximum_meteors = 8
        character._accuracy_chance = 20
        character._idle_max = 35
        character:set_texture(texture_omega)
    elseif rank == Rank.NM then
        character._health = 500
        character._attack = 300
        character._meteor_cooldown = 8
        character._minimum_meteors = 4
        character._maximum_meteors = 8
        character._accuracy_chance = 33
        character._idle_max = 30
        character:set_texture(texture_nm)
    else
        character._meteor_cooldown = 16
        character._minimum_meteors = 4
        character._maximum_meteors = 8
        character._attack = 40
        character._health = 150
        character._idle_max = 40
        character._accuracy_chance = 5
        character:set_texture(texture_v1)
    end

    shared_character_init(character)
end
