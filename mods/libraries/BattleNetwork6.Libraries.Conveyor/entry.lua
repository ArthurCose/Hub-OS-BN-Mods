local CONVEYOR_WAIT_DELAY = 6
local CONVEYOR_SLIDE_DURATION = 6

---@param custom_state CustomTileState
return function(custom_state, direction)
  local offset = Direction.vector(direction)
  local field = custom_state:field()

  local time_tracking = {}
  local slide_tracking = {}
  local on_tile_count = {}

  custom_state.on_entity_leave_func = function(self, entity)
    on_tile_count[entity:id()] = (on_tile_count[entity:id()] or 0) - 1
  end

  custom_state.on_entity_enter_func = function(self, entity)
    on_tile_count[entity:id()] = (on_tile_count[entity:id()] or 0) + 1
  end

  ---@param entity Entity
  local entity_update = function(entity)
    if entity:ignoring_negative_tile_effects() then
      return
    end

    if entity:is_moving() then
      local sliding = slide_tracking[entity:id()]

      if sliding then
        -- reset tracking
        time_tracking[entity:id()] = 0
      else
        time_tracking[entity:id()] = CONVEYOR_WAIT_DELAY
      end

      return
    end

    -- get and update movement tracking
    local elapsed_since_movement = time_tracking[entity:id()] or 0
    time_tracking[entity:id()] = elapsed_since_movement + 1
    slide_tracking[entity:id()] = nil

    if elapsed_since_movement < CONVEYOR_WAIT_DELAY then
      return
    end

    local current_tile = entity:current_tile()
    local dest = field:tile_at(current_tile:x() + offset.x, current_tile:y() + offset.y)


    if not entity:can_move_to(dest) then
      return
    end

    entity:slide(dest, CONVEYOR_SLIDE_DURATION)
    slide_tracking[entity:id()] = true
  end

  ---@param tile Tile
  custom_state.on_update_func = function(self, tile)
    for entity_id, count in pairs(on_tile_count) do
      if count == 0 then
        time_tracking[entity_id] = nil
        slide_tracking[entity_id] = nil
        on_tile_count[entity_id] = nil
      end
    end

    tile:find_characters(function(entity)
      entity_update(entity)
      return false
    end)
  end
end
