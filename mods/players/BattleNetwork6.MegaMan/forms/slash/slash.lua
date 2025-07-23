---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
local shared = require("../shared")

local FORM_MUG = _folder_path .. "mug.png"

local SLASH_TEXTURE = bn_assets.load_texture("slash_cross_charge_shot.png")
local SLASH_ANIMATION_PATH = bn_assets.fetch_animation_path("slash_cross_charge_shot.animation")
local SLASH_SFX = bn_assets.load_audio("sword.ogg")

local ANIMATION_PATH = _folder_path .. "battle.animation"

---@param player Entity
---@param form PlayerForm
---@param base_animation_path string
return function(player, form, base_animation_path)
  local sword_boost_aux_prop

  local form = shared.implement_form(player, form, {
    folder_path = _folder_path,
    base_animation_path = base_animation_path,
    element = Element.Sword,
    activate_callback = function()
      sword_boost_aux_prop = AuxProp.new()
          :require_card_element(Element.Sword)
          :require_card_time_freeze(false)
          :increase_card_damage(50)
      player:add_aux_prop(sword_boost_aux_prop)
    end,
    deactivate_callback = function()
      player:remove_aux_prop(sword_boost_aux_prop)
    end
  })

  form:set_mugshot_texture(FORM_MUG)

  form.normal_attack_func = function()
    return Buster.new(player, false, player:attack_level())
  end

  form.charged_attack_func = function()
    local action = Action.new(player, "CHARACTER_SWING")
    -- the split frames at the end are for setting anim actions at specific times
    action:override_animation_frames({ { 1, 2 }, { 2, 2 }, { 3, 2 }, { 4, 1 }, { 4, 15 }, { 4, 5 } })

    action:add_anim_action(2, function()
      local hand = action:create_attachment("HILT")

      local hand_sprite = hand:sprite()
      hand_sprite:set_texture(player:texture())
      hand_sprite:use_parent_shader(true)

      local hand_anim = hand:animation()
      hand_anim:load(ANIMATION_PATH)
      hand_anim:set_state("HAND")
    end)

    action:add_anim_action(5, function()
      Resources.play_audio(SLASH_SFX)

      player:set_counterable(true)

      local facing = player:facing()
      local tile = player:get_tile(facing, 1)

      if tile then
        local spell = Spell.new(player:team())
        spell:set_facing(facing)
        spell:set_texture(SLASH_TEXTURE)

        local spell_anim = spell:animation()
        spell_anim:load(SLASH_ANIMATION_PATH)
        spell_anim:set_state("DEFAULT")
        spell_anim:set_playback(Playback.Once)

        spell:set_hit_props(HitProps.new(
          20 * player:attack_level() + 60,
          Hit.Flinch | Hit.Flash,
          Element.None,
          player:context()
        ))

        local stopped = false
        local time = 0

        spell.on_update_func = function()
          time = time + 1

          if time > 5 then
            spell:delete()
            return
          end

          spell:attack_tile(spell:current_tile())
          local up = spell:get_tile(Direction.Up, 1)
          if up then spell:attack_tile(up) end
          local down = spell:get_tile(Direction.Down, 1)
          if down then spell:attack_tile(down) end

          if time < 2 or stopped or spell:is_moving() then
            return
          end

          spell:slide(spell:get_tile(facing, 1), 5)
        end

        spell.on_collision_func = function()
          stopped = true
        end

        player:field():spawn(spell, tile)
      end
    end)

    action:add_anim_action(6, function()
      player:set_counterable(false)
    end)

    action.on_action_end_func = function()
      player:set_counterable(false)
    end

    return action
  end

  local charge_timing = { 80, 70, 60, 55, 50 }
  form.calculate_charge_time_func = function()
    return charge_timing[player:charge_level()] or 50
  end

  -- todo sonic boom, maybe by reading the name to resolve the size?
  -- "swrd" exact = small,
  -- contains "long" = long
  -- default to wide
end
