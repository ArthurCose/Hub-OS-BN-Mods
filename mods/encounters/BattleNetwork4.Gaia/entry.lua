---@param encounter Encounter
function encounter_init(encounter)
  encounter:create_spawner("BattleNetwork4.Gaia.Enemy", Rank.V1)
      :spawn_at(4, 2)

  encounter:create_spawner("BattleNetwork4.Gaia.Enemy", Rank.EX)
      :spawn_at(5, 2)

  encounter:create_spawner("BattleNetwork4.Gaia+.Enemy", Rank.V1)
      :spawn_at(4, 1)

  encounter:create_spawner("BattleNetwork4.Gaia+.Enemy", Rank.EX)
      :spawn_at(5, 1)

  encounter:create_spawner("BattleNetwork4.GaiaMega.Enemy", Rank.V1)
      :spawn_at(4, 3)

  encounter:create_spawner("BattleNetwork4.GaiaMega.Enemy", Rank.EX)
      :spawn_at(5, 3)
end
