local package_id = "Dawn.BN3.Alpha"
local character_id = "Dawn.BN3.Alpha.BossFight"

function encounter_init(mob)
    local texPath = "background.png"
    local animPath = "background.animation"
    mob:set_background(texPath, animPath, 1.0, 0.0)
    mob:set_music("song.mid", 0, 0)

    mob:create_spawner(character_id, Rank.V1):spawn_at(5, 2)
end
