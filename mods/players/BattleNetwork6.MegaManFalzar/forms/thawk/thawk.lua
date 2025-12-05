---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
local shared = require("../shared")

local FORM_MUG = _folder_path .. "mug.png"

local SLASH_TEXTURE = bn_assets.load_texture("sword_slashes.png")
local SLASH_ANIMATION_PATH = bn_assets.fetch_animation_path("sword_slashes.animation")
local SLASH_SFX = bn_assets.load_audio("thawk_swing.ogg")

---@param player Entity
---@param form PlayerForm
---@param base_animation_path string
return function(player, form, base_animation_path)
  local wood_boost_aux_prop, status_guard_aux_prop

  shared.implement_form(player, form, {
    folder_path = _folder_path,
    base_animation_path = base_animation_path,
    element = Element.Wood,
    charge_timing = { 120, 110, 100, 95, 90 },
    activate_callback = function()
      wood_boost_aux_prop = AuxProp.new()
          :require_card_primary_element(Element.Wood)
          :require_card_time_freeze(false)
          :require_charged_card()
          :increase_card_multiplier(1)
      player:add_aux_prop(wood_boost_aux_prop)

      local immunities = Hit.Freeze | Hit.Paralyze | Hit.Blind | Hit.Confuse | Hit.Root

      if Hit.Bubble then
        immunities = immunities | Hit.Bubble
      end

      status_guard_aux_prop = AuxProp.new()
          :declare_immunity(immunities)
      player:add_aux_prop(status_guard_aux_prop)
    end,
    deactivate_callback = function()
      player:remove_aux_prop(wood_boost_aux_prop)
      player:remove_aux_prop(status_guard_aux_prop)
    end
  })

  form:set_mugshot_texture(FORM_MUG)

  form.normal_attack_func = function()
    return Buster.new(player, false, player:attack_level())
  end

  form.charged_attack_func = function()
    local action = Action.new(player, "CHARGED_ATTACK")

    action.on_execute_func = function()
      player:set_counterable(true)
    end

    action:on_anim_frame(2, function()
      player:set_counterable(false)
    end)

    action:on_anim_frame(5, function()
      Resources.play_audio(SLASH_SFX)

      local facing = player:facing()
      local tile = player:get_tile(facing, 1)

      if tile then
        local spell = Spell.new(player:team())
        spell:set_facing(facing)
        spell:set_texture(SLASH_TEXTURE)

        local spell_anim = spell:animation()
        spell_anim:load(SLASH_ANIMATION_PATH)
        spell_anim:set_state("TOMAHAWK_SWING")
        spell_anim:set_playback(Playback.Once)
        spell_anim:on_complete(function()
          spell:delete()
        end)

        spell:set_hit_props(HitProps.new(
          20 * player:attack_level() + 40,
          Hit.Flinch,
          Element.Wood,
          Element.Sword,
          player:context()
        ))

        ---@param center Tile?
        local function attack_column(center)
          if not center then return end
          spell:attack_tile(center)
          local up = center:get_tile(Direction.Up, 1)
          if up then spell:attack_tile(up) end
          local down = center:get_tile(Direction.Down, 1)
          if down then spell:attack_tile(down) end
        end

        spell.on_spawn_func = function()
          attack_column(spell:current_tile())
          attack_column(spell:get_tile(spell:facing(), 1))
        end

        Field.spawn(spell, tile)
      end
    end)

    action.on_action_end_func = function()
      player:set_counterable(false)
    end

    return action
  end

  form.calculate_card_charge_time_func = function(self, card_properties)
    if card_properties.element == Element.Wood and not card_properties.time_freeze then
      return 40
    end
  end

  form.charged_card_func = function(self, card_properties)
    return Action.from_card(player, card_properties)
  end
end
