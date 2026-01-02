local bn_assets = require("BattleNetwork.Assets")
---@type ShieldLib
local ShieldLib = require("dev.konstinople.library.shield")

local shield_impact_sfx = bn_assets.load_audio("guard.ogg")
local shield = ShieldLib.new_shield()
shield:set_default_shield_texture(bn_assets.load_texture("shield.png"))
shield:set_default_shield_animation_path(bn_assets.fetch_animation_path("shield.animation"))
shield:set_default_shield_animation_state("SHIELD")
shield:set_execute_sfx(bn_assets.load_audio("shield&reflect.ogg"))
shield:set_impact_texture(bn_assets.load_texture("shield_impact.png"))
shield:set_impact_animation_path(bn_assets.fetch_animation_path("shield_impact.animation"))
shield:set_duration(21)

---@param augment Augment
function augment_init(augment)
  local player = augment:owner()
  local attack = player:attack_level()
  local speed = player:rapid_level()
  local charge = player:charge_level()
  local cust = player:hand_size()

  local shield_cooldown = 0
  local component = player:create_component(Lifetime.ActiveBattle)

  --- calculate stats to boost
  if attack < 5 then
    player:boost_attack_level(5 - attack)
  end

  if speed < 5 then
    player:boost_rapid_level(5 - speed)
  end

  if charge < 5 then
    player:boost_charge_level(5 - charge)
  end

  if cust < 8 then
    player:boost_hand_size(8 - cust)
  end

  -- Float Shoes
  player:ignore_negative_tile_effects(true)

  -- Airshoes
  player:ignore_hole_tiles(true)

  -- Shield
  component.on_update_func = function()
    if shield_cooldown > 0 then
      shield_cooldown = shield_cooldown - 1
    end
  end

  augment.special_attack_func = function()
    if shield_cooldown > 0 then
      local action = Action.new(player)
      action:set_lockout(ActionLockout.new_sequence())
      return action
    end

    shield_cooldown = 40 + shield:duration()

    return shield:create_action(player, function()
      Resources.play_audio(shield_impact_sfx)
    end)
  end

  -- Undershirt
  local aux_prop = AuxProp.new()
      :require_total_damage(Compare.GT, 0)
      :decrease_total_damage("DAMAGE - clamp(DAMAGE, 1, HEALTH - 1)")
  player:add_aux_prop(aux_prop)

  augment.on_delete_func = function()
    player:remove_aux_prop(aux_prop)
    player:ignore_hole_tiles(false)
    player:ignore_negative_tile_effects(false)
    component:eject()
  end 
end