---@param encounter Encounter
function encounter_init(encounter)
  encounter:create_spawner("BattleNetwork4.GutsMan.Enemy", Rank.SP)
      :spawn_at(5, 2)
end
