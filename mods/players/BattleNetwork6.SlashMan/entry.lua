local bn_assets = require("BattleNetwork.Assets")
---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")

local FIXED_CARD_ID = "BattleNetwork6.Class06.Fixed.003.Gregar"

local CHARGE_TIMING = { 70, 60, 50, 40, 30 }

local KUNAI_TEXTURE = bn_assets.load_texture("bn6_kunai.png")
local KUNAI_ANIMATION_PATH = bn_assets.fetch_animation_path("bn6_kunai.animation")
local KUNAI_SHADOW = bn_assets.fetch_animation_path("bn6_kunai_shadow.png")
local SPIN_KUNAI_SFX = bn_assets.load_audio("kunai_spin.ogg")
local THROW_KUNAI_SFX = bn_assets.load_audio("physical_projectile.ogg")

local SLASH_SFX = bn_assets.load_audio("sword.ogg")

---@param player Entity
function player_init(player)
  player:set_height(43.0)
  player:load_animation("battle.animation")
  player:set_texture(Resources.load_texture("battle.png"))
  player:set_charge_position(2, -18)

  local sword_boost_aux_prop = AuxProp.new()
      :require_card_element(Element.Sword)
      :require_card_time_freeze(false)
      :increase_card_damage(50)
  player:add_aux_prop(sword_boost_aux_prop)

  player.normal_attack_func = function(self)
    return Buster.new(self, false, player:attack_level())
  end

  player.calculate_charge_time_func = function()
    return CHARGE_TIMING[player:charge_level()] or CHARGE_TIMING[#CHARGE_TIMING]
  end

  player.charged_attack_func = function()
    local action = Action.new(player, "CHARACTER_SWING_HAND")
    action:override_animation_frames({ { 1, 2 }, { 2, 2 }, { 3, 2 }, { 4, 40 } })

    action.on_execute_func = function()
      Resources.play_audio(SPIN_KUNAI_SFX)

      local function spawn_kunai(tile)
        if not tile or tile:is_edge() then
          return
        end

        local spell = Spell.new(player:team())
        spell:set_facing(player:facing())
        spell:set_texture(KUNAI_TEXTURE)
        spell:set_shadow(KUNAI_SHADOW)
        spell:set_elevation(20)

        local spell_anim = spell:animation()
        spell_anim:load(KUNAI_ANIMATION_PATH)
        spell_anim:set_state("SPIN")
        spell_anim:set_playback(Playback.Loop)
        spell_anim:on_complete(function()
        end)

        local loops = 0
        spell_anim:on_frame(6, function()
          if loops == 1 then
            spell_anim:set_state("POINT")
          end

          spell:attack_tile()

          loops = loops + 1
        end)

        spell:set_hit_props(HitProps.new(
          10 * player:attack_level() + 10,
          Hit.Flinch | Hit.Flash,
          Element.Sword,
          player:context()
        ))

        spell.on_spawn_func = function()
          spell:attack_tile()
        end

        local time = 0
        spell.on_update_func = function()
          time = time + 1

          if time < 35 then
            return
          elseif time == 35 then
            Resources.play_audio(THROW_KUNAI_SFX, AudioBehavior.NoOverlap)
          end

          spell:attack_tile()

          if spell:is_moving() then
            return
          end

          local next_tile = spell:get_tile(spell:facing(), 1)

          if not next_tile then
            spell:delete()
            return
          end

          spell:slide(next_tile, 7)
        end

        spell.on_collision_func = function()
          if time >= 35 then
            spell:delete()
          end
        end

        Field.spawn(spell, tile)
      end

      local facing = player:facing()
      spawn_kunai(player:get_tile(facing, 1))
      spawn_kunai(player:get_tile(Direction.Up, 1))
      spawn_kunai(player:get_tile(Direction.Down, 1))
    end

    return action
  end

  -- -- fixed card
  local card = CardProperties.from_package(FIXED_CARD_ID, "S")
  player:set_fixed_card(card)

  -- emotions
  player.on_counter_func = function()
    player:set_emotion("SYNCHRO")
  end

  local synchro = EmotionsLib.new_synchro()
  synchro:implement(player)

  -- intro
  player.intro_func = function()
    local action = Action.new(player, "SLASH_FORWARD")
    action:set_lockout(ActionLockout.new_sequence())

    local time = 0
    local step = action:create_step()
    step.on_update_func = function()
      if time > 42 then
        step:complete_step()
      end

      time = time + 1
    end

    action.on_execute_func = function()
      Resources.play_audio(SLASH_SFX)

      local animation = player:animation()
      animation:on_complete(function()
        Resources.play_audio(SLASH_SFX)

        animation:set_state("SLASH_DOWN")
        animation:on_complete(function()
          animation:set_state("ROLLING_SLASH_END")
        end)
      end)
    end

    return action
  end
end
