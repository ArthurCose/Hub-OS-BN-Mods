local CONVEYOR_WAIT_DELAY = 7
local CONVEYOR_SLIDE_DURATION = 7

---@param custom_state CustomTileState
return function(custom_state, direction)
  local offset = Direction.vector(direction)
  local field = custom_state:field()

  local tracking = {}

  custom_state.on_entity_leave_func = function(self, entity)
    tracking[entity:id()] = nil
  end

  ---@param entity Entity
  local entity_update = function(entity)
    if entity:ignoring_negative_tile_effects() then
      return
    end

    if entity:is_moving() then
      -- reset tracking
      tracking[entity:id()] = 0
      return
    end

    -- get and update movement tracking
    local elapsed_since_movement = tracking[entity:id()] or 0
    tracking[entity:id()] = elapsed_since_movement + 1

    if elapsed_since_movement < CONVEYOR_WAIT_DELAY then
      return
    end

    local current_tile = entity:current_tile()
    local dest = field:tile_at(current_tile:x() + offset.x, current_tile:y() + offset.y)


    if not entity:can_move_to(dest) then
      return
    end

    entity:slide(dest, CONVEYOR_SLIDE_DURATION)
  end

  ---@param tile Tile
  custom_state.on_update_func = function(self, tile)
    tile:find_characters(function(entity)
      entity_update(entity)
      return false
    end)
  end
end
