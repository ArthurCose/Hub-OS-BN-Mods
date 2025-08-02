local package_id = "com.Dawn.Viruses.FighterPlane"
local character_id = "com.Dawn.Viruses.Enemy.FighterPlane"


function encounter_init(mob)
  mob
      :create_spawner(character_id, Rank.V1)
      :spawn_at(5, 2)
  mob
      :create_spawner(character_id, Rank.V2)
      :spawn_at(4, 1)
  mob
      :create_spawner(character_id, Rank.V3)
      :spawn_at(6, 3)
end
