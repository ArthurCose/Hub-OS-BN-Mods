local bn_assets = require("BattleNetwork.Assets")
---@type PanelStepLib
local PanelStepLib = require("dev.konstinople.library.panel_step")
---@type ShieldLib
local ShieldLib = require("dev.konstinople.library.shield")
---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")

local panel_step = PanelStepLib.new_panel_step()

local shield_impact_sfx = bn_assets.load_audio("guard.ogg")
local shield = ShieldLib.new_shield()
shield:set_execute_sfx(bn_assets.load_audio("shield&reflect.ogg"))
shield:set_impact_texture(bn_assets.load_texture("shield_impact.png"))
shield:set_impact_animation_path(bn_assets.fetch_animation_path("shield_impact.animation"))
shield:set_duration(21)

local shield_reflect = ShieldLib.new_reflect()
shield_reflect:set_attack_texture(bn_assets.load_texture("buster_charged_impact.png"))
shield_reflect:set_attack_animation_path(bn_assets.fetch_animation_path("buster_charged_impact.animation"))

local FIXED_CARD_ID = "BattleNetwork6.Class06.Fixed.006"

---@param player Entity
function player_init(player)
  player:set_height(47.0)
  player:load_animation("battle.animation")
  player:set_texture(Resources.load_texture("battle.png"))

  player.normal_attack_func = function(self)
    return Buster.new(self, false, player:attack_level())
  end

  player.calculate_charge_time_func = function()
    -- 10-30
    return 35 - math.min(player:charge_level(), 5) * 5
  end

  player.charged_attack_func = function(self)
    local card_properties = CardProperties.from_package("BattleNetwork6.Class01.Standard.071")
    card_properties.damage = 60 + player:attack_level() * 20
    return Action.from_card(self, card_properties)
  end

  -- shield
  local shield_cooldown = 0

  player.on_update_func = function()
    if shield_cooldown > 0 then
      shield_cooldown = shield_cooldown - 1
    end
  end

  player.special_attack_func = function()
    if shield_cooldown > 0 then
      local action = Action.new(player)
      action:set_lockout(ActionLockout.new_sequence())
      return action
    end

    shield_cooldown = 40 + shield:duration()
    local hit = false

    return shield:create_action(player, function()
      Resources.play_audio(shield_impact_sfx)

      if hit then
        return
      end

      shield_reflect:spawn_spell(player, 50)
      hit = true
    end)
  end

  -- 2x sword chips
  player:add_aux_prop(AuxProp.new():require_charged_card():increase_card_multiplier(1))

  player.calculate_card_charge_time_func = function(self, card)
    local can_charge = not card.time_freeze and
        (card.element == Element.Sword or card.secondary_element == Element.Sword) and
        card.package_id ~= FIXED_CARD_ID

    if not can_charge then
      return
    end

    return 50
  end

  player.charged_card_func = function(self, card)
    local action = Action.from_card(self, card)

    if action then
      return panel_step:wrap_action(action)
    end
  end

  -- fixed card
  local card = CardProperties.from_package(FIXED_CARD_ID, "B")
  card.damage = 60 + player:attack_level() * 20
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
    card.damage = 60 + attack_level * 20
    button = player:set_fixed_card(card)
  end

  -- emotions
  player.on_counter_func = function()
    player:set_emotion("SYNCHRO")
  end

  local synchro = EmotionsLib.new_synchro()
  synchro:set_ring_offset(0, -math.floor(player:height() / 2))
  synchro:implement(player)
end
