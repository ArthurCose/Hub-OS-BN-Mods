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
  local entity = augment:owner()

  local shield_cooldown = 0
  local component = entity:create_component(Lifetime.Battle)

  component.on_update_func = function()
    if shield_cooldown > 0 then
      shield_cooldown = shield_cooldown - 1
    end
  end

  augment.special_attack_func = function()
    if shield_cooldown > 0 then
      return
    end

    shield_cooldown = 40 + shield:duration()

    return shield:create_action(entity, function()
      Resources.play_audio(shield_impact_sfx)
    end)
  end

  augment.on_delete_func = function()
    component:eject()
  end
end
