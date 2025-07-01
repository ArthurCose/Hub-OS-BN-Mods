---@param custom_state CustomTileState
function tile_state_init(custom_state)
  local field = custom_state:field()
  local tracked_auxprops = {}

  custom_state.on_entity_enter_func = function(self, entity)
    if not Character.from(entity) and not Obstacle.from(entity) then
      return
    end

    if tracked_auxprops[entity:id()] then
      print("entity entered ice tile twice without leaving?")
      return
    end

    local aux_prop = AuxProp.new()
        :require_hit_element(Element.Aqua)
        :with_callback(function()
          entity:apply_status(Hit.Freeze, 150)
          entity:current_tile():set_state(TileState.Normal)
        end)

    entity:add_aux_prop(aux_prop)
    tracked_auxprops[entity:id()] = aux_prop
  end

  custom_state.on_entity_leave_func = function(self, entity)
    local aux_prop = tracked_auxprops[entity:id()]

    if aux_prop then
      entity:remove_aux_prop(aux_prop)
      tracked_auxprops[entity:id()] = nil
    end
  end

  custom_state.on_replace_func = function(self, tile)
    for id in pairs(tracked_auxprops) do
      local entity = field:get_entity(id)

      if not entity then
        tracked_auxprops[id] = nil
        goto continue
      end

      if entity:current_tile() == tile then
        local aux_prop = tracked_auxprops[id]
        entity:remove_aux_prop(aux_prop)
        tracked_auxprops[id] = nil
      end

      ::continue::
    end
  end

  custom_state.on_entity_stop_func = function(self, entity, prev_tile)
    if entity:element() == Element.Aqua then
      return
    end

    if not entity:is_dragged() and entity:ignoring_negative_tile_effects() then
      return
    end

    local current_tile = entity:current_tile()

    local x_diff = current_tile:x() - prev_tile:x()
    local y_diff = current_tile:y() - prev_tile:y()
    local x_inc = 0
    local y_inc = 0

    if x_diff > 0 then
      x_inc = 1
    elseif x_diff < 0 then
      x_inc = -1
    elseif y_diff > 0 then
      y_inc = 1
    elseif y_diff < 0 then
      y_inc = -1
    else
      return
    end

    local dest = field:tile_at(current_tile:x() + x_inc, current_tile:y() + y_inc)

    if not entity:can_move_to(dest) then
      return
    end

    entity:slide(dest, 4)
  end
end
