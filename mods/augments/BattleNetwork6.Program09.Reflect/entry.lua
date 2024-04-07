local bn_assets = require("BattleNetwork.Assets")
---@type ShieldLib
local ShieldLib = require("dev.konstinople.library.shield")

local shield_impact_sfx = bn_assets.load_audio("guard.ogg")
local shield = ShieldLib.new_shield()
shield:set_default_shield_texture(bn_assets.load_texture("shield.png"))
shield:set_default_shield_animation_path(bn_assets.fetch_animation_path("shield.animation"))
shield:set_default_shield_animation_state("REFLECT_RED")
shield:set_execute_sfx(bn_assets.load_audio("shield&reflect.ogg"))
shield:set_impact_texture(bn_assets.load_texture("shield_impact.png"))
shield:set_impact_animation_path(bn_assets.fetch_animation_path("shield_impact.animation"))
shield:set_duration(21)


local shield_reflect = ShieldLib.new_reflect()
shield_reflect:set_attack_texture(bn_assets.load_texture("buster_charged_impact.png"))
shield_reflect:set_attack_animation_path(bn_assets.fetch_animation_path("buster_charged_impact.animation"))

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
    local hit = false

    return shield:create_action(entity, function()
      Resources.play_audio(shield_impact_sfx)

      if hit then
        return
      end

      shield_reflect:spawn_spell(entity, 50)
      hit = true
    end)
  end

  augment.on_delete_func = function()
    component:eject()
  end
end
