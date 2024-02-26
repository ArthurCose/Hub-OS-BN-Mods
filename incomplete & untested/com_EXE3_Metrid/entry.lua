local package_id = "EXE3.Metrid"
local character_id = "EXE3.Metrid.Enemy"





function encounter_init(mob)
    mob:create_spawner(character_id, Rank.V1):spawn_at(4, 1)
    mob:create_spawner(character_id, Rank.V2):spawn_at(4, 3)
    mob:create_spawner(character_id, Rank.V3):spawn_at(6, 1)
    mob:create_spawner(character_id, Rank.SP):spawn_at(6, 3)
    -- mob:create_spawner(character_id, Rank.NM):spawn_at(5, 2)
end