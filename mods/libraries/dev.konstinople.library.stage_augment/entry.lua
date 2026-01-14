---@class dev.konstinople.library.stage_augment
local Lib = {}

---@param user Entity
---@param callback fun(tile: Tile)
function Lib.set_stage(user, callback)
  -- start off by changing the entire stage
  Field.find_tiles(function(tile)
    callback(tile)
    return false
  end)

  local component = user:create_component(Lifetime.Scene)
  local i = 0

  component.on_update_func = function()
    if i == 0 then
      -- change same team tiles to prevent opponent stage augments from overriding our change
      Field.find_tiles(function(tile)
        if tile:team() == user:team() then
          tile:set_state(TileState.Normal)
          callback(tile)
        end
        return false
      end)
    elseif i == 1 then
      -- change just the tile we're on to avoid teammates from overriding us completely
      local tile = user:current_tile()
      tile:set_state(TileState.Normal)
      callback(tile)
      component:eject()
    end

    i = i + 1
  end
end

return Lib
