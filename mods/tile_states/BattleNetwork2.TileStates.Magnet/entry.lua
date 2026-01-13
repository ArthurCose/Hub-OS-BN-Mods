local CONVEYOR_WAIT_DELAY = 16
local CONVEYOR_SLIDE_DURATION = 4

---@param custom_state CustomTileState
function tile_state_init(custom_state)
    local tracking = {}

    custom_state.on_entity_leave_func = function(self, entity)
        tracking[entity:id()] = 0
    end

    ---@param entity Entity
    local entity_update = function(entity)
        if entity:ignoring_negative_tile_effects() then return end

        if entity:is_moving() then
            -- reset tracking
            tracking[entity:id()] = 0
            return
        end

        local direction = nil
        local current_tile = entity:current_tile()

        -- Do not drag if already on a magnet tile
        if current_tile:state() == TileState.Magnet then return end

        local up_tile = current_tile:get_tile(Direction.Up, 1)
        local down_tile = current_tile:get_tile(Direction.Down, 1)

        if up_tile and up_tile:state() == TileState.Magnet then
            direction = Direction.Up
        elseif down_tile and down_tile:state() == TileState.Magnet then
            direction = Direction.Down
        end

        if direction == nil then return end

        -- get and update movement tracking
        local elapsed_since_movement = tracking[entity:id()] or 0
        tracking[entity:id()] = elapsed_since_movement + 1

        if elapsed_since_movement < CONVEYOR_WAIT_DELAY then return end

        local dest = current_tile:get_tile(direction, 1)

        if not entity:can_move_to(dest) then return end

        entity:slide(dest, CONVEYOR_SLIDE_DURATION)
    end

    ---@param tile Tile
    custom_state.on_update_func = function(self, tile)
        Field.find_characters(function(entity)
            entity_update(entity)
            return false
        end)
    end
end
