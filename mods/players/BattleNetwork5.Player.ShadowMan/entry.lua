---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")

local create_ninja_star_action = require("./attacks/ninja_star")
local create_antidamage_generator = require("./attacks/antidamage")

local FIXED_CARD_ID = "BattleNetwork5.Class06.Fixed.002.Colonel"

---@param player Entity
function player_init(player)
  player:set_height(72.0)
  player:set_texture(Resources.load_texture("battle.png"))
  player:load_animation("battle.animation")
  player:set_shadow(Resources.load_texture("shadow.png"), "shadow.animation")
  player:set_charge_position(6, -42)

  player:ignore_negative_tile_effects()

  -- emotions
  local emotions = EmotionsLib.implement_supported_full(player)
  emotions.synchro:set_ring_animation_state("BIG")

  -- attacks
  player.normal_attack_func = function()
    return Buster.new(player, false, player:attack_level())
  end

  player.charged_attack_func = function()
    local hit_props = HitProps.new(
      player:attack_level() * 20,
      Hit.Flinch,
      Element.Sword,
      player:context()
    )
    return create_ninja_star_action(player, hit_props)
  end

  local generator = create_antidamage_generator(player)
  player.special_attack_func = function()
    local hit_props = HitProps.new(
      50,
      Hit.Flinch,
      Element.Sword,
      player:context()
    )
    return generator(hit_props)
  end

  -- fixed card
  local card = CardProperties.from_package(FIXED_CARD_ID, "S")
  player:set_fixed_card(card)

  -- -- intro
  -- player.intro_func = function()
  --   player:hide()

  --   local action = Action.new(player, "CHARACTER_MOVE")
  --   action:override_animation_frames({ { 4, 1 }, { 3, 1 }, { 2, 1 }, { 1, 16 } })

  --   action.on_execute_func = function()
  --     player:reveal()
  --   end

  --   return action
  -- end
end
