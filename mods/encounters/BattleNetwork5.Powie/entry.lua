local powie_id = "BattleNetwork5.Powie.Enemy"
local powie2_id = "BattleNetwork5.Powie2.Enemy"
local powie3_id = "BattleNetwork5.Powie3.Enemy"

---@param encounter Encounter
function encounter_init(encounter)
  encounter:set_field_size(9, 5)

  encounter
      :create_spawner(powie_id, Rank.V1)
      :spawn_at(4, 2)
  encounter
      :create_spawner(powie_id, Rank.EX)
      :spawn_at(6, 2)

  encounter
      :create_spawner(powie2_id, Rank.V1)
      :spawn_at(5, 1)
  encounter
      :create_spawner(powie2_id, Rank.EX)
      :spawn_at(7, 1)

  encounter
      :create_spawner(powie3_id, Rank.V1)
      :spawn_at(5, 3)
  encounter
      :create_spawner(powie3_id, Rank.EX)
      :spawn_at(7, 3)
end
