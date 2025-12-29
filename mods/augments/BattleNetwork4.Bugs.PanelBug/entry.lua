---@param augment Augment
function augment_init(augment)
  local player = augment:owner()
  local component = player:create_component(Lifetime.ActiveBattle)
  ---@type Tile?
  local last_tile = nil

  component.on_update_func = function()
    local current_tile = player:current_tile()

    if last_tile == current_tile then
      return
    end

    local state = { TileState.Cracked, TileState.Dark, TileState.Poison }

    if last_tile and last_tile:state() ~= TileState.Broken then
      last_tile:set_state(state[math.min(3, augment:level())])
    end

    last_tile = current_tile
  end

  player:boost_augment("BattleNetwork.Bugs.EmotionFlicker", 1)

  augment.on_delete_func = function()
    player:boost_augment("BattleNetwork.Bugs.EmotionFlicker", -1)
    component:eject()
  end
end
