---@param encounter Encounter
function encounter_init(encounter)
  encounter:create_spawner("BattleNetwork5.BlizzardMan.Enemy", Rank.Omega)
      :spawn_at(5, 2)
end
