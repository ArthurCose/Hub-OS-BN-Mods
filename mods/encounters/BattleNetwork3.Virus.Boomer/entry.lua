-- Original mod by: loui1

-- To spawn this enemy use
-- BattleNetwork3.enemy.Boomer
-- BattleNetwork3.enemy.Gloomer
-- BattleNetwork3.enemy.Doomer

---@param encounter Encounter
function encounter_init(encounter)
  -- local character_id =
  encounter
      :create_spawner("BattleNetwork3.enemy.Boomer", Rank.SP)
      :spawn_at(4, 1)

  -- local spawner = mob:create_spawner("BattleNetwork3.enemy.Boomer", Rank.Rare1)
  -- spawner:spawn_at(5, 2)

  -- local spawner = mob:create_spawner("BattleNetwork3.enemy.Boomer", Rank.Rare2)
  -- spawner:spawn_at(6, 3)

  encounter
      :create_spawner("BattleNetwork3.enemy.Gloomer", Rank.V1)
      :spawn_at(5, 2)

  encounter
      :create_spawner("BattleNetwork3.enemy.Doomer", Rank.V1)
      :spawn_at(6, 3)
  -- :mutate(function(entity)
  --   local panel_grab = CardProperties.from_package("BattleNetwork6.Class01.Standard.164")
  --   entity:insert_field_card(1, panel_grab)
  --   entity:insert_field_card(1, panel_grab)
  -- end)
end
