local character_id = "BattleNetwork6.Viruses.Gunner.Enemy"

function encounter_init(mob)
  local field = mob:field()

  local tile = field:tile_at(4, 2)

  if not tile:is_walkable() then
    tile:set_state(TileState.Normal)
  end

  mob
      :create_spawner(character_id, Rank.V2)
      :spawn_at(6, 3)

  mob
      :create_spawner(character_id, Rank.V1)
      :spawn_at(4, 2)

  mob
      :create_spawner(character_id, Rank.V3)
      :spawn_at(6, 1)
end
