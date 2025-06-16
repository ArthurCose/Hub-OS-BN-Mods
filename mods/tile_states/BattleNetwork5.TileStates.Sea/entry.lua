local FIRE_DRAIN_INTERVAL = 7 -- copied from poison, uncertain of accuracy

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
        :require_hit_element(Element.Elec)
        :increase_hit_damage("DAMAGE")
    entity:add_aux_prop(double_damage_prop)

    local card_aux_prop = AuxProp.new()
        :require_card_element(Element.Aqua)
        :increase_card_damage(30)
        :with_callback(function()
          entity:current_tile():set_state(TileState.Normal)
        end)
    entity:add_aux_prop(card_aux_prop)

    local drain_aux_prop = AuxProp.new()
        :require_element(Element.Fire)
        :require_interval(FIRE_DRAIN_INTERVAL)
        :require_negative_tile_interaction()
        :drain_health(1)
    entity:add_aux_prop(drain_aux_prop)

    tracked_auxprops[entity:id()] = {
      double_damage_prop,
      card_aux_prop,
      drain_aux_prop,
    }
  end

  custom_state.on_entity_leave_func = function(self, entity)
    local aux_props = tracked_auxprops[entity:id()]

    if not aux_props then
      return
    end

    if entity:current_tile():state() == TileState.Sea then
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
  end

  custom_state.on_entity_stop_func = function(self, entity)
    -- Do not process if entity is deleted or slated for erasure.
    if entity:deleted() or entity:will_erase_eof() then return end

    -- Do not process if entity is deleted or slated for easure.
    if entity:ignoring_negative_tile_effects() then return end

    -- Do not affect spells or obstacles.
    if Spell.from(entity) ~= nil or Obstacle.from(entity) ~= nil then return end

    -- Do not affect Aqua entities.
    if entity:element() == Element.Aqua then return end

    entity:apply_status(Hit.Root, 20)

    local artifact = Artifact.new()
    artifact:set_texture("splash.png")
    artifact:set_never_flip(true)

    local artifact_animation = artifact:animation()
    artifact_animation:load("splash.animation")
    artifact_animation:set_state("DEFAULT")
    artifact_animation:on_complete(function()
      artifact:delete()
    end)

    field:spawn(artifact, entity:current_tile())
  end
end
