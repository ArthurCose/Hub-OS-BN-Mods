---@param custom_state CustomTileState
function tile_state_init(custom_state)
  local field = custom_state:field()
  local tracked_auxprops = {}

  custom_state.on_entity_enter_func = function(self, entity)
    if not Character.from(entity) and not Obstacle.from(entity) then
      return
    end

    if tracked_auxprops[entity:id()] then
      -- already applied
      return
    end

    local double_damage_prop = AuxProp.new()
        :require_hit_element(Element.Aqua)
        :increase_hit_damage("DAMAGE")
    entity:add_aux_prop(double_damage_prop)

    tracked_auxprops[entity:id()] = { double_damage_prop }

    if entity:ignoring_negative_tile_effects() or entity:element() == Element.Fire then
      return
    end

    entity:hit(HitProps.new(50, Hit.Flinch | Hit.Impact, Element.Fire))

    local tile = entity:current_tile()
    field:spawn(Explosion.new(), tile)
    tile:set_state(TileState.Normal)
  end

  custom_state.on_entity_leave_func = function(self, entity)
    local aux_props = tracked_auxprops[entity:id()]

    if not aux_props then
      return
    end

    if entity:current_tile():state() == TileState.Grass then
      -- no need to remove aux props
      return
    end

    for _, aux_prop in ipairs(aux_props) do
      entity:remove_aux_prop(aux_prop)
    end

    tracked_auxprops[entity:id()] = nil
  end

  custom_state.change_request_func = function(self, tile)
    for id in pairs(tracked_auxprops) do
      local entity = field:get_entity(id)

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

    return true
  end
end
