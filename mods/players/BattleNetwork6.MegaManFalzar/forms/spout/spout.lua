---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
local shared = require("../shared")

local FORM_MUG = _folder_path .. "mug.png"

local BUBBLER_BUSTER_TEXTURE = bn_assets.load_texture("bn4_bubbler_buster.png")
local BUBBLER_BUSTER_ANIMATION_PATH = bn_assets.fetch_animation_path("bn4_bubbler_buster.animation")
local BUBBLES_TEXTURE = bn_assets.load_texture("bn4_bubble_impact.png")
local BUBBLES_ANIMATION_PATH = bn_assets.fetch_animation_path("bn4_bubble_impact.animation")
local BUBBLES_SFX = bn_assets.load_audio("bubbler.ogg")
local SHOOT_SFX = bn_assets.load_audio("spreader.ogg")

local RECOVER_TEXTURE = bn_assets.load_texture("recover.png")
local RECOVER_ANIMATION_PATH = bn_assets.fetch_animation_path("recover.animation")
local RECOVER_SFX = bn_assets.load_audio("recover.ogg")

---@param player Entity
---@param form PlayerForm
---@param base_animation_path string
return function(player, form, base_animation_path)
  local aqua_charge_aux_prop
  local aqua_heal_aux_prop

  shared.implement_form(player, form, {
    folder_path = _folder_path,
    base_animation_path = base_animation_path,
    element = Element.Aqua,
    charge_timing = { 60, 50, 40, 30, 20 },
    activate_callback = function()
      aqua_charge_aux_prop = AuxProp.new()
          :require_card_element(Element.Aqua)
          :require_card_time_freeze(false)
          :require_charged_card()
          :increase_card_multiplier(1)
      player:add_aux_prop(aqua_charge_aux_prop)

      aqua_heal_aux_prop = AuxProp.new()
          :require_card_element(Element.Aqua)
          :require_card_time_freeze(false)
          :increase_card_multiplier(0)
          :with_callback(function()
            player:set_health(player:health() + math.min(player:max_health() * 0.05, 50))

            Resources.play_audio(RECOVER_SFX)

            local artifact = Artifact.new()
            artifact:set_texture(RECOVER_TEXTURE)
            artifact:sprite():set_layer(-2)

            local artifact_anim = artifact:animation()
            artifact_anim:load(RECOVER_ANIMATION_PATH)
            artifact_anim:set_state("DEFAULT")
            artifact_anim:on_complete(function()
              artifact:delete()
            end)

            Field.spawn(artifact, player:current_tile())
          end)
      player:add_aux_prop(aqua_heal_aux_prop)
    end,
    deactivate_callback = function()
      player:remove_aux_prop(aqua_charge_aux_prop)
      player:remove_aux_prop(aqua_heal_aux_prop)
    end
  })

  form:set_mugshot_texture(FORM_MUG)

  form.normal_attack_func = function()
    return Buster.new(player, false, player:attack_level())
  end

  form.charged_attack_func = function()
    local action = Action.new(player, "CHARACTER_SHOOT")
    action:override_animation_frames(
      { { 1, 1 }, { 2, 3 }, { 3, 3 }, { 4, 9 }, { 4, 6 } }
    )

    action:set_lockout(ActionLockout.new_animation())

    action.on_execute_func = function()
      Resources.play_audio(SHOOT_SFX)
      player:set_counterable(true)

      local buster = action:create_attachment("BUSTER")
      local buster_sprite = buster:sprite()
      buster_sprite:set_texture(BUBBLER_BUSTER_TEXTURE)
      buster_sprite:set_layer(-1)
      buster_sprite:use_root_shader()

      local buster_anim = buster:animation()
      buster_anim:load(BUBBLER_BUSTER_ANIMATION_PATH)
      buster_anim:set_state("BN6")

      -- immediately spawn the attack
      local spell = Spell.new(player:team())
      spell:set_facing(player:facing())

      local hit_props = HitProps.new(
        10 * player:attack_level() + 20,
        Hit.Flinch | Hit.Flash,
        Element.Aqua,
        player:context(),
        Drag.None
      )

      local last_tile = player:current_tile()

      spell.on_update_func = function()
        spell:attack_tile(last_tile)
        spell:attack_tile()
        last_tile = spell:current_tile()

        if spell:is_moving() then
          return
        end

        local next_tile = spell:get_tile(spell:facing(), 1)

        if next_tile then
          spell:slide(next_tile, 2)
        else
          spell:delete()
        end
      end

      spell.on_collision_func = function()
        if spell:deleted() then
          return
        end

        spell:delete()

        Resources.play_audio(BUBBLES_SFX)

        local function spawn_bubbles(tile)
          if not tile then
            return
          end

          local bubbles = Spell.new(spell:team())
          bubbles:set_facing(spell:facing())
          bubbles:set_hit_props(hit_props)
          bubbles:set_texture(BUBBLES_TEXTURE)

          bubbles.on_spawn_func = function()
            bubbles:attack_tile()
          end

          local bubbles_anim = bubbles:animation()
          bubbles_anim:load(BUBBLES_ANIMATION_PATH)
          bubbles_anim:set_state("BN6")
          bubbles_anim:on_complete(function()
            bubbles:delete()
          end)

          Field.spawn(bubbles, tile)
        end

        spawn_bubbles(spell:current_tile())
        spawn_bubbles(spell:get_tile(spell:facing(), 1))
      end

      Field.spawn(spell, last_tile)
    end

    action:add_anim_action(5, function()
      player:set_counterable(false)
    end)

    action.on_action_end_func = function()
      player:set_counterable(false)
    end

    return action
  end

  form.calculate_card_charge_time_func = function(self, card_properties)
    if card_properties.element == Element.Aqua and not card_properties.time_freeze then
      return 40
    end
  end

  form.charged_card_func = function(self, card_properties)
    return Action.from_card(player, card_properties)
  end
end
