---@param augment Augment
function augment_init(augment)
  local player = augment:owner()
  local width = Field.width()
  local height = Field.height()
  local tile
  local state = TileState.Cracked
  if augment:level() >= 2 then state = TileState.Poison end
  for x = 1, width, 1 do
    for y = 1, height, 1 do
      tile = Field.tile_at(x, y)
      if tile and tile:state() == TileState.Normal and player:is_team(tile:team()) then
        tile:set_state(state)
      end
    end
  end

  player:boost_augment("BattleNetwork.Bugs.EmotionFlicker", 1)

  augment.on_delete_func = function()
    player:boost_augment("BattleNetwork.Bugs.EmotionFlicker", -1)
  end
end
