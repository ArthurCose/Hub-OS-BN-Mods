local character_id = "EXE3.Basher.Enemy"

function encounter_init(mob)
    mob:create_spawner(character_id, Rank.V1):spawn_at(5, 2)
end