---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
local shared = require("../shared")

local FORM_MUG = _folder_path .. "mug.png"

local BEAM_TEXTURE = Resources.load_texture("delete_beam.png")
local BEAM_ANIMATION_PATH = _folder_path .. "delete_beam.animation"
local BEAM_SFX = bn_assets.load_audio("dollthunder.ogg")


---@param player Entity
---@param form PlayerForm
---@param base_animation_path string
return function(player, form, base_animation_path)
  local cursor_boost_aux_prop, death_curse_aux_prop
  local death_curse_active = false
  local defense_rules = {}

  local form = shared.implement_form(player, form, {
    folder_path = _folder_path,
    base_animation_path = base_animation_path,
    element = Element.Cursor,
    activate_callback = function()
      cursor_boost_aux_prop = AuxProp.new()
          :require_card_element(Element.Cursor)
          :increase_card_damage(30)
      player:add_aux_prop(cursor_boost_aux_prop)

      death_curse_aux_prop = AuxProp.new():intercept_action(function(action)
        local card_properties = action:copy_card_properties()
        death_curse_active = card_properties.package_id and card_properties.element == Element.None
        return action
      end)
      player:add_aux_prop(death_curse_aux_prop)
    end,
    deactivate_callback = function()
      player:remove_aux_prop(cursor_boost_aux_prop)
      player:remove_aux_prop(death_curse_aux_prop)

      for entity_id, defense_rule in pairs(defense_rules) do
        local entity = Field:get_entity(entity_id)

        if entity then
          entity:remove_defense_rule(defense_rule)
        end
      end
    end
  })

  form:set_mugshot_texture(FORM_MUG)

  -- create death curse listeners as defense rules
  form.on_update_func = function()
    player:field():find_characters(function(entity)
      -- already installed
      if defense_rules[entity:id()] then
        return false
      end

      -- not a player, ignore for now
      -- todo: we should add an hp bug for bosses (not currently possible)
      -- and just delete if it's a basic enemy (not currently differentiable)
      if not Player.from(entity) then
        return false
      end

      -- create a new defense rule
      local defense_rule = DefenseRule.new(DefensePriority.Last, DefenseOrder.CollisionOnly)

      defense_rule.defense_func = function(defense, attacker, defender, hit_props)
        if defense:damage_blocked() then
          return
        end

        if hit_props.context.aggressor ~= player:id() or not death_curse_active then
          return
        end

        if defender:health() % 10 == 4 then
          defender:boost_augment("BattleNetwork6.Bugs.BattleHPBug", 1)
        end
      end

      entity:add_defense_rule(defense_rule)
      defense_rules[entity:id()] = defense_rule

      return false
    end)
  end

  form.normal_attack_func = function()
    return Buster.new(player, false, player:attack_level())
  end

  form.charged_attack_func = function()
    local action = Action.new(player, "CHARGED_ATTACK")

    local frames = { { 1, 2 }, { 1, 14 }, { 1, 56 } }

    action:override_animation_frames(frames)

    action.on_execute_func = function()
      player:set_counterable(true)
    end

    action:add_anim_action(2, function()
      Resources.play_audio(BEAM_SFX)

      local facing = player:facing()
      local tile = player:get_tile(facing, 1)

      if tile then
        local spell = Spell.new(player:team())
        spell:set_facing(facing)
        spell:set_texture(BEAM_TEXTURE)

        local spell_anim = spell:animation()
        spell_anim:load(BEAM_ANIMATION_PATH)
        spell_anim:set_state("START")
        spell_anim:set_playback(Playback.Loop)

        local active = false

        spell_anim:on_complete(function()
          spell_anim:set_state("LOOP")
          spell_anim:set_playback(Playback.Loop)
          active = true
        end)

        spell:set_hit_props(HitProps.new(
          20 * player:attack_level() + 40,
          Hit.Flinch | Hit.Flash | Hit.PierceInvis,
          Element.None,
          player:context()
        ))

        local attack_list = { tile }

        for i = 1, 4 do
          local new_tile = tile:get_tile(facing, i)
          if new_tile then
            attack_list[#attack_list + 1] = new_tile
          end
        end

        local time = 0

        spell.on_update_func = function()
          time = time + 1

          if not active then
            return
          end

          for _, tile in ipairs(attack_list) do
            spell:attack_tile(tile)
          end

          if time < 62 then
            return
          end

          spell.on_update_func = nil
          spell_anim:set_state("END")
          spell_anim:on_complete(function()
            spell:delete()
          end)
        end

        player:field():spawn(spell, tile)
      end
    end)

    action:add_anim_action(3, function()
      player:set_counterable(false)
    end)

    action.on_action_end_func = function()
      player:set_counterable(false)
    end

    return action
  end

  local charge_timing = { 110, 100, 90, 85, 80 }
  form.calculate_charge_time_func = function()
    return charge_timing[player:charge_level()] or 80
  end
end
