---@param encounter Encounter
function encounter_init(encounter)
  if math.random(2) == 1 then
    encounter:create_spawner("BattleNetwork6.Cragger.Enemy", Rank.V1):spawn_at(4, 1)
    encounter:create_spawner("BattleNetwork6.Cragger.Enemy", Rank.V2):spawn_at(5, 3)
    encounter:create_spawner("BattleNetwork6.Cragger.Enemy", Rank.V3):spawn_at(6, 2)
  else
    encounter:create_spawner("BattleNetwork6.Cragger.Enemy", Rank.SP):spawn_at(4, 2)
    encounter:create_spawner("BattleNetwork6.Cragger.Enemy", Rank.Rare1):spawn_at(6, 1)
    encounter:create_spawner("BattleNetwork6.Cragger.Enemy", Rank.Rare2):spawn_at(6, 3)
  end
end
