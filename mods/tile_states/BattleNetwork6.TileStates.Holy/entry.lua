---@param custom_state CustomTileState
function tile_state_init(custom_state)
  local tracked_auxprops = {}

  custom_state.on_entity_enter_func = function(self, entity)
    if not Character.from(entity) and not Obstacle.from(entity) then
      return
    end

    if tracked_auxprops[entity:id()] then
      -- already applied
      return
    end

    local half_damage_prop = AuxProp.new()
        :decrease_total_damage("DAMAGE / 2")
    entity:add_aux_prop(half_damage_prop)

    tracked_auxprops[entity:id()] = { half_damage_prop }
  end

  custom_state.on_entity_leave_func = function(self, entity)
    local aux_props = tracked_auxprops[entity:id()]

    if not aux_props then
      return
    end

    if entity:current_tile():state() == TileState.Holy then
      -- no need to remove aux props
      return
    end

    for _, aux_prop in ipairs(aux_props) do
      entity:remove_aux_prop(aux_prop)
    end

    tracked_auxprops[entity:id()] = nil
  end

  custom_state.on_replace_func = function(self, tile)
    for id in pairs(tracked_auxprops) do
      local entity = Field.get_entity(id)

      if not entity then
        tracked_auxprops[id] = nil
        goto continue
      end

      if entity:current_tile() == tile then
        local aux_props = tracked_auxprops[id]

        for _, aux_prop in ipairs(aux_props) do
          entity:remove_aux_prop(aux_prop)
        end

        tracked_auxprops[entity:id()] = nil
      end

      ::continue::
    end
  end
end
