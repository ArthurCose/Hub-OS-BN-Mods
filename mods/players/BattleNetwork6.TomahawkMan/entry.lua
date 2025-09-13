local bn_assets = require("BattleNetwork.Assets")
---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")

local FIXED_CARD_ID = "BattleNetwork6.Class06.Fixed.002.Falzar"

local CHARGE_TIMING = { 120, 110, 100, 95, 90 }

local SLASH_TEXTURE = bn_assets.load_texture("sword_slashes.png")
local SLASH_ANIMATION_PATH = bn_assets.fetch_animation_path("sword_slashes.animation")
local SLASH_SFX = bn_assets.load_audio("thawk_swing.ogg")

---@param player Entity
function player_init(player)
  player:set_height(43.0)
  player:load_animation("battle.animation")
  player:set_texture(Resources.load_texture("battle.png"))
  player:set_charge_position(2, -18)

  local immunities = Hit.Flinch | Hit.Freeze | Hit.Paralyze | Hit.Blind | Hit.Confuse | Hit.Root | Hit.Bubble
  player:add_aux_prop(AuxProp.new():declare_immunity(immunities))

  player.normal_attack_func = function(self)
    return Buster.new(self, false, player:attack_level())
  end

  player.calculate_charge_time_func = function()
    return CHARGE_TIMING[player:charge_level()] or CHARGE_TIMING[#CHARGE_TIMING]
  end

  player.charged_attack_func = function()
    local action = Action.new(player, "CHARGED_ATTACK")

    action.on_execute_func = function()
      player:set_counterable(true)
    end

    action:add_anim_action(2, function()
      player:set_counterable(false)
    end)

    action:add_anim_action(5, function()
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

  -- 2x wood chips
  player:add_aux_prop(AuxProp.new():require_charged_card():increase_card_multiplier(1))

  player.calculate_card_charge_time_func = function(self, card)
    local can_charge = not card.time_freeze and
        (card.element == Element.Wood or card.secondary_element == Element.Wood) and
        card.package_id ~= FIXED_CARD_ID

    if not can_charge then
      return
    end

    return 50
  end

  player.charged_card_func = function(self, card)
    return Action.from_card(self, card)
  end

  -- fixed card
  local card = CardProperties.from_package(FIXED_CARD_ID, "T")
  card.damage = 100 + player:attack_level() * 30
  local button = player:set_fixed_card(card)

  local component = player:create_component(Lifetime.CardSelectOpen)

  local prev_attack_level = player:attack_level()
  component.on_update_func = function()
    if button:deleted() then
      component:eject()
      return
    end

    local attack_level = player:attack_level()

    if attack_level == prev_attack_level then
      return
    end

    button:delete()

    prev_attack_level = attack_level
    card.damage = 100 + attack_level * 30
    button = player:set_fixed_card(card)
  end

  -- emotions
  player.on_counter_func = function()
    player:set_emotion("SYNCHRO")
  end

  local synchro = EmotionsLib.new_synchro()
  synchro:set_ring_offset(2, -18)
  synchro:implement(player)
end
