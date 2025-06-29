---@param encounter Encounter
function encounter_init(encounter)
  encounter:create_spawner("BattleNetwork4.FireMan.Enemy", Rank.SP)
      :spawn_at(5, 2)
end
