---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
local shared = require("../shared")

local FORM_MUG = _folder_path .. "mug.png"

-- no idea if this is correct
local TACKLE_SFX = bn_assets.load_audio("dust_chute2.ogg")
local HIT_SFX = bn_assets.load_audio("hit_impact.ogg")

---@param player Entity
---@param form PlayerForm
---@param base_animation_path string
return function(player, form, base_animation_path)
  local charge_boost_aux_prop, detect_charge_aux_prop
  local boost_custom_component
  local custom_boosts = 0
  local charging_chip = false
  local chip_charge_time = 0

  shared.implement_form(player, form, {
    folder_path = _folder_path,
    base_animation_path = base_animation_path,
    element = Element.Fire,
    activate_callback = function()
      detect_charge_aux_prop = AuxProp.new()
          :require_card_charge_time(Compare.GT, 0)
          :with_callback(function()
            charging_chip = true
          end)
      player:add_aux_prop(detect_charge_aux_prop)

      boost_custom_component = player:create_component(Lifetime.CardSelectOpen)
      boost_custom_component.on_update_func = function()
        if custom_boosts < 3 then
          player:boost_augment("HubOS.Augments.Custom1", 1)
          custom_boosts = custom_boosts + 1
        end
      end
    end,
    deactivate_callback = function()
      player:remove_aux_prop(detect_charge_aux_prop)

      if charge_boost_aux_prop then
        player:remove_aux_prop(charge_boost_aux_prop)
      end

      boost_custom_component:eject()

      if custom_boosts > 0 then
        player:boost_augment("HubOS.Augments.Custom1", -custom_boosts)
      end
    end
  })

  form:set_mugshot_texture(FORM_MUG)

  -- handle boosting chip charge
  form.on_update_func = function()
    if not charging_chip then
      chip_charge_time = 0

      if charge_boost_aux_prop then
        player:remove_aux_prop(charge_boost_aux_prop)
        charge_boost_aux_prop = nil
      end

      return
    end

    charging_chip = false

    if chip_charge_time >= 500 then
      -- already reached max charge
      return
    end

    chip_charge_time = chip_charge_time + 1

    if chip_charge_time % 5 ~= 0 then
      -- return early if a change isn't necessary
      return
    end

    if charge_boost_aux_prop then
      player:remove_aux_prop(charge_boost_aux_prop)
      charge_boost_aux_prop = nil
    end

    charge_boost_aux_prop = AuxProp.new()
        :require_card_element(Element.Fire)
        :increase_card_damage(math.min(chip_charge_time // 5, 100))

    player:add_aux_prop(charge_boost_aux_prop)
  end

  -- back to attacks
  form.normal_attack_func = function()
    return Buster.new(player, false, player:attack_level())
  end

  local animation = player:animation()

  form.charged_attack_func = function()
    local action = Action.new(player, "CHARGE_START")
    action:set_lockout(ActionLockout.new_sequence())

    local windup_step = action:create_step()
    local tackle_step = action:create_step()
    local idle_step = action:create_step()
    local poof_step = action:create_step()

    local movements = 0
    local start_tile, invulnerability

    local spell = Spell.new(player:team())
    spell:set_hit_props(HitProps.new(
      20 * player:attack_level() + 30,
      Hit.Impact | Hit.Flinch | Hit.Flash | Hit.PierceGuard,
      Element.Fire,
      player:context()
    ))

    local hit = false
    local action_ended = false

    spell.on_collision_func = function(_, other)
      hit = true
      tackle_step:complete_step()

      local offset_x = math.random(-Tile:width() / 2, Tile:width())
      local offset_y = math.random(-player:height(), 0)
      shared.spawn_hit_artifact(other, "FIRE", offset_x, offset_y)

      Resources.play_audio(HIT_SFX)
    end

    tackle_step.on_update_func = function()
      spell:attack_tile(player:current_tile())

      if player:is_moving() then return end

      if movements >= 3 then
        tackle_step:complete_step()
        return
      end

      player:slide(player:get_tile(player:facing(), 1), 5)
      movements = movements + 1
    end

    local idle_time = 0
    idle_step.on_update_func = function()
      if not hit then
        -- we only idle if we've hit something
        idle_step:complete_step()
      end

      idle_time = idle_time + 1

      if idle_time >= 12 then
        idle_step:complete_step()
      end
    end

    poof_step.on_update_func = function()
      poof_step.on_update_func = nil

      local poof = bn_assets.MobMove.new("BIG_END")
      local offset_x = Tile:width() // 4
      local offset_y = -player:height() // 2

      if player:facing() == Direction.Left then
        offset_x = -offset_x
      end

      poof:set_offset(offset_x, offset_y)

      poof.on_spawn_func = function()
        player:current_tile():remove_entity(player)
      end

      poof:animation():on_complete(function()
        -- we need a new poof, since the assets lib auto deletes it
        poof = bn_assets.MobMove.new("BIG_START")
        local poof_anim = poof:animation()

        player:field():spawn(poof, start_tile)
        poof:set_offset(0, offset_y)

        poof_anim:on_frame(2, function()
          if not action_ended then
            start_tile:add_entity(player)
            poof_step:complete_step()
          end
        end)

        poof_anim:on_complete(function()
          poof:delete()
        end)
      end)

      player:field():spawn(poof, player:current_tile())
    end

    action.on_execute_func = function()
      player:set_counterable(true)
      animation:on_complete(function()
        windup_step:complete_step()

        Resources.play_audio(TACKLE_SFX)

        animation:set_state("CHARGE_LOOP")
        animation:set_playback(Playback.Loop)
        start_tile = player:current_tile()

        invulnerability = DefenseRule.new(DefensePriority.Action, DefenseOrder.Always)
        invulnerability.defense_func = function(defense)
          defense:block_impact()
          defense:block_damage()
        end
        player:add_defense_rule(invulnerability)
        player:set_counterable(false)
      end)
    end

    action.can_move_to_func = function(tile)
      -- custom can_move_to_func to allow movement over enemy tiles
      return not tile:is_edge() and (tile:is_walkable() or player:ignoring_hole_tiles())
    end

    action.on_action_end_func = function()
      action_ended = true

      player:set_counterable(false)

      if spell then
        spell:delete()
      end

      if start_tile then
        player:current_tile():remove_entity(player)
        start_tile:add_entity(player)
      end

      if invulnerability then
        player:remove_defense_rule(invulnerability)
      end
    end

    return action
  end

  local charge_timing = { 90, 80, 70, 65, 60 }
  form.calculate_charge_time_func = function()
    return charge_timing[player:charge_level()] or 60
  end

  form.calculate_card_charge_time_func = function(self, card_properties)
    if card_properties.element == Element.Fire and not card_properties.time_freeze then
      return 500
    end
  end

  form.charged_card_func = function(self, card_properties)
    -- already boosted by auxprops
    return Action.from_card(player, card_properties)
  end
end
