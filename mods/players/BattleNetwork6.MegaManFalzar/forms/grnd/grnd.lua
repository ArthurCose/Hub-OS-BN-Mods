---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
---@type BattleNetwork.FallingRock
local FallingRockLib = require("BattleNetwork.FallingRock")
local shared = require("../shared")

local FORM_MUG = _folder_path .. "mug.png"

local DRILL_TEXTURE = bn_assets.load_texture("drill_arm.png")
local DRILL_ANIMATION_PATH = bn_assets.fetch_animation_path("drill_arm.animation")
local DRILL_SFX = bn_assets.load_audio("drillarm3.ogg")

---@param player Entity
---@param form PlayerForm
---@param base_animation_path string
return function(player, form, base_animation_path)
  local break_boost_aux_prop
  local rock_aux_prop

  shared.implement_form(player, form, {
    folder_path = _folder_path,
    base_animation_path = base_animation_path,
    element = Element.Break,
    charge_timing = { 100, 90, 80, 75, 70 },
    activate_callback = function()
      break_boost_aux_prop = AuxProp.new()
          :require_card_primary_element(Element.Break)
          :require_card_time_freeze(false)
          :increase_card_damage(10)
      player:add_aux_prop(break_boost_aux_prop)

      rock_aux_prop = AuxProp.new()
          :require_card_primary_element(Element.Break)
          :require_card_time_freeze(false)
          :require_charged_card()
          :increase_card_multiplier(0)
          :with_callback(function()
            local hit_props =
                HitProps.new(
                  20 * player:attack_level() + 30,
                  Hit.Flinch,
                  Element.Break
                )

            FallingRockLib.spawn_falling_rocks(player:team(), 3, hit_props)
            Field.shake(3, 40)
          end)
      player:add_aux_prop(rock_aux_prop)

      player:boost_augment("BattleNetwork6.Program01.SuperArmor", 1)
    end,
    deactivate_callback = function()
      player:remove_aux_prop(break_boost_aux_prop)
      player:remove_aux_prop(rock_aux_prop)
      player:boost_augment("BattleNetwork6.Program01.SuperArmor", -1)
    end
  })

  form:set_mugshot_texture(FORM_MUG)

  form.normal_attack_func = function()
    return Buster.new(player, false, player:attack_level())
  end


  form.charged_attack_func = function()
    local action = Action.new(player, "CHARGED_ATTACK")

    local time = 0
    local initial_contact = false
    ---@type Tile | nil, Tile | nil
    local original_tile, temp_tile
    ---@type Entity | nil
    local hole

    local function spawn_attack()
      local spawn_tile = player:get_tile(player:facing(), 1)

      if not spawn_tile then return end

      local spell = Spell.new(player:team())
      spell:set_facing(player:facing())
      spell:set_hit_props(
        HitProps.new(
          10 * player:attack_level() + 10,
          Hit.PierceGuard | Hit.PierceGround | Hit.Drag,
          Element.Break,
          player:context(),
          Drag.new(player:facing(), 1)
        )
      )

      spell.on_spawn_func = function()
        spell:attack_tile()
        spell:attack_tile(spell:get_tile(spell:facing(), 1))
        spell:delete()
      end

      local hit = false

      spell.on_collision_func = function(_, other)
        if not hit then
          Field.shake(2, 30)
          hit = true
        end

        shared.spawn_hit_artifact(
          other,
          "BREAK",
          math.random(-Tile:width() / 2, Tile:width() / 2),
          math.random(-other:height(), 0)
        )
      end

      Field.spawn(spell, spawn_tile)
    end

    action.on_update_func = function()
      time = time + 1

      if time == 40 then
        player:set_counterable(true)
        spawn_attack()
      elseif time == 39 then
        -- first hit on 40 (1f spawn delay)
        spawn_attack()
      elseif time == 42 and initial_contact then
        -- second hit on 43 (1f spawn delay)
        spawn_attack()
      elseif time == 50 and not initial_contact then
        -- second hit on 51 (1f spawn delay)
        spawn_attack()
      elseif time == 53 and initial_contact then
        -- third hit on 54 (1f spawn delay)
        spawn_attack()
      elseif time == 56 then
        player:set_counterable(false)
      elseif time == 62 and not initial_contact then
        -- third hit on 63 (1f spawn delay)
        spawn_attack()
      end
    end

    action:on_anim_frame(2, function()
      hole = Artifact.new()
      hole:set_texture(player:texture())
      local hole_anim = hole:animation()
      hole_anim:copy_from(player:animation())
      hole_anim:set_state("HOLE")

      local tile = player:current_tile()
      Field.spawn(hole, tile)
      tile:remove_entity(player)
    end)

    action:on_anim_frame(3, function()
      if hole then
        hole:delete()
      end

      local i = 1
      local last_tile
      local last_friendly_tile
      local found_enemy = false

      while true do
        local tile = player:get_tile(player:facing(), i)
        i = i + 1

        if not tile or tile:is_edge() then
          break
        end

        if tile:is_walkable() and not tile:is_reserved() then
          last_tile = tile

          if player:can_move_to(tile) then
            last_friendly_tile = tile
          end
        end

        tile:find_characters(function(c)
          if c:team() ~= player:team() and c:hittable() then
            found_enemy = true
          end

          return false
        end)

        if found_enemy then
          break
        end
      end

      temp_tile = last_friendly_tile

      if found_enemy then
        temp_tile = last_tile
      end

      if not temp_tile then
        temp_tile = original_tile
      end

      if temp_tile then
        temp_tile:add_entity(player)
        temp_tile:reserve_for(player)
      end
    end)

    ---@type Attachment | nil
    local drill
    action:on_anim_frame(5, function()
      Resources.play_audio(DRILL_SFX)
      drill = action:create_attachment("BUSTER")
      local drill_sprite = drill:sprite()
      drill_sprite:set_texture(DRILL_TEXTURE)
      drill_sprite:use_parent_shader()
      local drill_anim = drill:animation()
      drill_anim:load(DRILL_ANIMATION_PATH)
      drill_anim:set_state("DEFAULT")
    end)

    -- spawn poof
    action:on_anim_frame(6, function()
      if drill then
        drill:sprite():hide()
      end

      if not original_tile or not temp_tile then
        return
      end

      local poof_a = bn_assets.MobMove.new("BIG_START")
      local poof_b = bn_assets.MobMove.new("BIG_END")
      poof_a:set_offset(0, -player:height() // 2)
      poof_b:set_offset(0, -player:height() // 2)

      Field.spawn(poof_a, player:current_tile())
      Field.spawn(poof_b, original_tile)
    end)

    -- disappear
    action:on_anim_frame(7, function()
      if not temp_tile then
        return
      end

      if temp_tile then
        temp_tile:remove_reservation_for(player)
        temp_tile = nil
      end

      player:current_tile():remove_entity(player)
    end)

    -- return
    action:on_anim_frame(8, function()
      if not original_tile then
        return
      end

      if original_tile then
        original_tile:add_entity(player)
        original_tile = nil
      end
    end)

    action.on_execute_func = function()
      original_tile = player:current_tile()
    end

    action.on_action_end_func = function()
      player:set_counterable(false)

      if hole then
        hole:delete()
      end

      if temp_tile then
        temp_tile:remove_reservation_for(player)
      end

      if original_tile then
        player:current_tile():remove_entity(player)
        original_tile:add_entity(player)
      end
    end

    return action
  end

  form.calculate_card_charge_time_func = function(self, card_properties)
    if card_properties.element == Element.Break and not card_properties.time_freeze then
      return 60
    end
  end

  form.charged_card_func = function(self, card_properties)
    return Action.from_card(player, card_properties)
  end
end
