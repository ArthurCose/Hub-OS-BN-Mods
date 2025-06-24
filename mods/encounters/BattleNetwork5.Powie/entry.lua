local powie_id = "BattleNetwork5.Powie.Enemy"
local powie2_id = "BattleNetwork5.Powie2.Enemy"
local powie3_id = "BattleNetwork5.Powie3.Enemy"


function encounter_init(encounter)
  encounter:spawn_player(1, 3, 2)

  encounter
      :create_spawner(powie_id, Rank.V1)
      :spawn_at(4, 3)
  encounter
      :create_spawner(powie_id, Rank.EX)
      :spawn_at(6, 1)

  -- encounter
  --   :create_spawner(powie_id, Rank.V1)
  --   :spawn_at(5, 2)
  -- encounter
  --   :create_spawner(powie_id, Rank.EX)
  --   :spawn_at(6, 2)

  -- encounter
  --   :create_spawner(powie2_id, Rank.V1)
  --   :spawn_at(5, 1)
  -- encounter
  --   :create_spawner(powie2_id, Rank.EX)
  --   :spawn_at(6, 1)

  -- encounter
  --   :create_spawner(powie3_id, Rank.V1)
  --   :spawn_at(5, 3)
  -- encounter
  --   :create_spawner(powie3_id, Rank.EX)
  --   :spawn_at(6, 3)
end
