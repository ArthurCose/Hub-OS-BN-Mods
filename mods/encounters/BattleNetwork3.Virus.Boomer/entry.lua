-- Original mod by: loui1

-- To spawn this enemy use
-- BattleNetwork3.enemy.Boomer
-- BattleNetwork3.enemy.Gloomer
-- BattleNetwork3.enemy.Doomer

function encounter_init(mob)
  -- local character_id =
  local spawner = mob:create_spawner("BattleNetwork3.enemy.Boomer", Rank.SP)
  spawner:spawn_at(4, 1)

  -- local spawner = mob:create_spawner("BattleNetwork3.enemy.Boomer", Rank.Rare1)
  -- spawner:spawn_at(5, 2)

  -- local spawner = mob:create_spawner("BattleNetwork3.enemy.Boomer", Rank.Rare2)
  -- spawner:spawn_at(6, 3)

  local spawner = mob:create_spawner("BattleNetwork3.enemy.Gloomer", Rank.V1)
  spawner:spawn_at(5, 2)

  local spawner = mob:create_spawner("BattleNetwork3.enemy.Doomer", Rank.V1)
  spawner:spawn_at(6, 3)
end
