---@param encounter Encounter
function encounter_init(encounter)
  encounter:create_spawner("BattleNetwork4.Bass.Enemy", Rank.Omega)
      :spawn_at(5, 2)
end
