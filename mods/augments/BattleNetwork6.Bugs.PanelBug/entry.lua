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

    if last_tile and last_tile:state() ~= TileState.Broken then
      local chance = math.min(augment:level() + 1, 4) -- [2, 4]
      local roll = math.random(1, 8)

      if roll <= chance then
        last_tile:set_state(TileState.Cracked)
      end
    end

    last_tile = current_tile
  end

  augment.on_delete_func = function()
    component:eject()
  end
end
