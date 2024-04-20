local package_id = "com.Dawn.Requested.Catack"
local character_id = "com.Dawn.Requested.Enemy.Catack"





function encounter_init(mob)
  mob
    :create_spawner(character_id, Rank.V1)
    :spawn_at(4, 2)
  mob
    :create_spawner(character_id, Rank.V2)
    :spawn_at(4, 1)
  mob
    :create_spawner(character_id, Rank.V3)
    :spawn_at(4, 3)
  mob
    :create_spawner(character_id, Rank.SP)
    :spawn_at(6, 2)
end
