---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")

local LUNGE_SFX = Resources.load_audio("lunge.ogg")

local TEXTURE = Resources.load_texture("battle.png")
local ANIM_PATH = "battle.animation"

local VASE_TEXTURE = Resources.load_texture("vase.png")
local VASE_ANIM_PATH = "vase.animation"

local SHADOW_TEXTURE = Resources.load_texture("shadow.png")
local SHADOW_ANIM_PATH = "shadow.animation"

---@param s string
---@param value string
local function starts_with(s, value)
  return s:sub(1, #value) == value
end

---@param player Entity
function player_init(player)
  player:set_height(78.0)
  player:set_texture(TEXTURE)
  player:load_animation(ANIM_PATH)
  player:set_shadow(SHADOW_TEXTURE, SHADOW_ANIM_PATH)
  player:set_charge_position(-2, -50)

  player:ignore_hole_tiles()

  -- emotions
  EmotionsLib.implement_supported_full(player)

  -- +30 wood chips
  player:add_aux_prop(
    AuxProp.new():require_card_element(Element.Wood):increase_card_damage(30)
  )

  -- vase
  local anim = player:animation()

  local vase = Spell.new()
  vase:set_layer(1)
  vase:set_texture(VASE_TEXTURE)
  vase:set_shadow(SHADOW_TEXTURE, SHADOW_ANIM_PATH)

  local vase_anim = vase:animation()
  vase_anim:load(VASE_ANIM_PATH)

  -- create fallback vase for environments where scripts can't run
  local fallback_vase = player:create_sync_node()
  fallback_vase:sprite():set_texture(VASE_TEXTURE)
  fallback_vase:sprite():set_layer(1)
  fallback_vase:animation():load(VASE_ANIM_PATH)

  -- immediately delete the fallback vase in a normal battle
  local fallback_cleanup_component = player:create_component(Lifetime.Scene)
  fallback_cleanup_component.on_update_func = function()
    player:remove_sync_node(fallback_vase)
    fallback_cleanup_component:eject()
  end

  -- regular animation
  vase_anim:set_state("DEFAULT")
  vase_anim:set_playback(Playback.Loop)

  Field.spawn(vase, player:current_tile())

  local vase_sync_component = vase:create_component(Lifetime.Scene)
  vase_sync_component.on_update_func = function()
    if player:deleted() then
      vase:delete()
      return
    end

    local state = anim:state()

    if
        not starts_with(state, "CHARACTER_IDLE") and
        not starts_with(state, "CHARACTER_MOVE") and
        not starts_with(state, "CHARACTER_THROW")
    then
      vase:hide()
      return
    end

    vase:reveal()

    local movement_offset = player:movement_offset()
    local offset = player:offset()
    vase:set_offset(offset.x + movement_offset.x, offset.y + movement_offset.y)
    vase:set_elevation(player:elevation())
    vase:set_facing(player:facing())
    player:current_tile():add_entity(vase)
  end

  -- attacks

  player.normal_attack_func = function()
    return Buster.new(player, false, player:attack_level())
  end

  -- copied from elec cross
  local CHARGE_TIMING = { 90, 80, 70, 65, 60 }
  player.calculate_charge_time_func = function()
    return CHARGE_TIMING[player:charge_level()] or CHARGE_TIMING[#CHARGE_TIMING]
  end

  player.charged_attack_func = function()
    local action = Action.new(player, "SNAKE_BITE_START")
    action:override_animation_frames({ { 1, 8 } })
    action:set_lockout(ActionLockout.new_sequence())

    local spell = Spell.new(player:team())
    local hit_props = HitProps.new(
      player:attack_level() * 15,
      Hit.Flinch,
      Element.Wood,
      player:context()
    )
    spell:set_hit_props(hit_props)

    local counterable_step = action:create_step()
    local lunge_step = action:create_step()
    local loop_step = action:create_step()
    local retract_step = action:create_step()

    local time = 0
    lunge_step.on_update_func = function()
      time = time + 1

      spell:attack_tile(player:current_tile())
      spell:attack_tile(player:get_tile(player:facing(), 1))

      if time > 2 then
        spell:attack_tile(player:get_tile(player:facing(), 2))
      end

      if time < 5 then
        return
      end

      lunge_step:complete_step()

      anim:set_state("SNAKE_BITE_LOOP")
      anim:set_playback(Playback.Loop)

      local loops = 0
      anim:on_complete(function()
        loops = loops + 1

        -- hit for every bite
        spell:attack_tile(player:get_tile(player:facing(), 3))

        if loops < 3 then
          return
        end

        loop_step:complete_step()

        anim:set_state("SNAKE_BITE_END")
        anim:on_complete(function()
          retract_step:complete_step()
        end)
      end)
    end

    loop_step.on_update_func = function()
      spell:attack_tile(player:current_tile())
      spell:attack_tile(player:get_tile(player:facing(), 1))
      spell:attack_tile(player:get_tile(player:facing(), 2))
    end

    action.on_execute_func = function()
      Field.spawn(spell, player:current_tile())

      player:set_counterable(true)

      anim:on_complete(function()
        player:set_counterable(false)

        counterable_step:complete_step()
        anim:set_state("SNAKE_BITE_START")

        Resources.play_audio(LUNGE_SFX)
      end)
    end

    action.on_action_end_func = function()
      player:set_counterable(false)
      spell:delete()
    end

    return action
  end

  -- adds wind element to wood chips
  player.calculate_card_charge_time_func = function(self, card)
    if card.element == Element.Wood and card.secondary_element == Element.None and card.can_boost then
      return 60
    end
  end

  player.charged_card_func = function(self, card)
    card.secondary_element = Element.Wind
    return Action.from_card(player, card)
  end
end
