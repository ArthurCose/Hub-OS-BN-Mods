local POISON_DRAIN_INTERVAL = 7

---@param custom_state CustomTileState
function tile_state_init(custom_state)
  local tracked_auxprops = {}

  custom_state.on_entity_enter_func = function(self, entity)
    if not Character.from(entity) and not Obstacle.from(entity) then
      return
    end

    if not entity:ignoring_negative_tile_effects() then
      -- drain one hp immediately
      local aux_prop = AuxProp.new()
          :drain_health(1)
          :immediate()
      entity:add_aux_prop(aux_prop);
    end

    if tracked_auxprops[entity:id()] then
      -- already applied
      return
    end

    local drain_aux_prop = AuxProp.new()
        :require_negative_tile_interaction()
        :require_interval(POISON_DRAIN_INTERVAL)
        :drain_health(1)
    entity:add_aux_prop(drain_aux_prop)

    tracked_auxprops[entity:id()] = {
      drain_aux_prop,
    }
  end

  custom_state.on_entity_leave_func = function(self, entity)
    local aux_props = tracked_auxprops[entity:id()]

    if not aux_props then
      return
    end

    if entity:current_tile():state() == TileState.Poison then
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
