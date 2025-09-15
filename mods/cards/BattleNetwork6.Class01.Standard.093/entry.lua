local bn_assets = require("BattleNetwork.Assets")
---@type ShieldLib
local ShieldLib = require("dev.konstinople.library.shield")

local shield_impact_sfx = bn_assets.load_audio("guard.ogg")
local shield = ShieldLib.new_shield()
shield:set_execute_sfx(bn_assets.load_audio("shield&reflect.ogg"))
shield:set_shield_texture(bn_assets.load_texture("shield.png"))
shield:set_shield_animation_path(bn_assets.fetch_animation_path("shield.animation"))
shield:set_shield_animation_state("REFLECTOR_3")
shield:set_impact_texture(bn_assets.load_texture("shield_impact.png"))
shield:set_impact_animation_path(bn_assets.fetch_animation_path("shield_impact.animation"))
shield:set_duration(63)

local shield_reflect = ShieldLib.new_reflect()
shield_reflect:set_attack_texture(bn_assets.load_texture("buster_charged_impact.png"))
shield_reflect:set_attack_animation_path(bn_assets.fetch_animation_path("buster_charged_impact.animation"))

---@param user Entity
function card_init(user, props)
	local hit = false

	return shield:create_action(user, function()
		Resources.play_audio(shield_impact_sfx)

		if hit then
			return
		end

		shield_reflect:spawn_spell(user, props.damage)
		hit = true
	end)
end
