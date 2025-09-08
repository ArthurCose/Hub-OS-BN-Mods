---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
local shared = require("../shared")

local FORM_MUG = _folder_path .. "mug.png"

local THUNDERBOLT_TEXTURE = Resources.load_texture("thunderbolt.png")
local THUNDERBOLT_ANIMATION_PATH = _folder_path .. "thunderbolt.animation"
local THUNDERBOLT_SFX = bn_assets.load_audio("dollthunder.ogg")

---@param player Entity
---@param form PlayerForm
---@param base_animation_path string
return function(player, form, base_animation_path)
  local elec_boost_aux_prop

  shared.implement_form(player, form, {
    folder_path = _folder_path,
    base_animation_path = base_animation_path,
    element = Element.Elec,
    charge_timing = { 90, 80, 70, 65, 60 },
    activate_callback = function()
      elec_boost_aux_prop = AuxProp.new()
          :require_card_element(Element.Elec)
          :require_card_time_freeze(false)
          :increase_card_damage(50)
      player:add_aux_prop(elec_boost_aux_prop)
    end,
    deactivate_callback = function()
      player:remove_aux_prop(elec_boost_aux_prop)
    end
  })

  form:set_mugshot_texture(FORM_MUG)

  form.normal_attack_func = function()
    return Buster.new(player, false, player:attack_level())
  end

  form.charged_attack_func = function()
    local action = Action.new(player, "CHARACTER_SHOOT")

    local frames = { { 1, 10 }, { 1, 3 }, { 2, 2 }, { 1, 3 }, { 2, 2 }, { 1, 3 }, { 2, 2 }, { 1, 6 } }

    action:override_animation_frames(frames)

    action.on_execute_func = function()
      local buster = action:create_attachment("BUSTER")

      local buster_sprite = buster:sprite()
      buster_sprite:set_texture(player:texture())
      buster_sprite:use_root_shader()

      local buster_anim = buster:animation()
      buster_anim:load(_folder_path .. "battle.animation")
      buster_anim:set_state("BUSTER", frames)

      player:set_counterable(true)
    end

    action:add_anim_action(2, function()
      Resources.play_audio(THUNDERBOLT_SFX)

      local facing = player:facing()
      local tile = player:get_tile(facing, 1)

      if tile then
        local spell = Spell.new(player:team())
        spell:set_facing(facing)
        spell:set_texture(THUNDERBOLT_TEXTURE)

        local spell_anim = spell:animation()
        spell_anim:load(THUNDERBOLT_ANIMATION_PATH)
        spell_anim:set_state("DEFAULT")
        spell_anim:set_playback(Playback.Loop)

        spell:set_hit_props(HitProps.new(
          20 * player:attack_level() + 40,
          Hit.Flinch | Hit.Flash,
          Element.Elec,
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
          for _, tile in ipairs(attack_list) do
            spell:attack_tile(tile)
          end

          time = time + 1

          if time >= 14 then
            spell:delete()
          end
        end

        spell.on_collision_func = function(_, other)
          shared.spawn_hit_artifact(other, "ELEC", math.random(-8, 8), -other:height() // 2 + math.random(-8, 8))
        end

        Field.spawn(spell, tile)
      end
    end)

    action:add_anim_action(4, function()
      player:set_counterable(false)
    end)

    action.on_action_end_func = function()
      player:set_counterable(false)
    end

    return action
  end

  form.calculate_card_charge_time_func = function(self, card_properties)
    if card_properties.element == Element.None and not card_properties.time_freeze then
      return 60
    end
  end

  form.charged_card_func = function(self, card_properties)
    card_properties.hit_flags = card_properties.hit_flags | Hit.Paralyze
    return Action.from_card(player, card_properties)
  end
end
