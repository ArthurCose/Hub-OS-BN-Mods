---@type dev.konstinople.library.sword
local SwordLib = require("dev.konstinople.library.sword")
---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local TEXTURE = bn_assets.load_texture("moonblade.png")
local ANIMATION_PATH = bn_assets.fetch_animation_path("moonblade.animation")
local AUDIO = bn_assets.load_audio("whip_attack.ogg")

local sword = SwordLib.new_sword()
sword:use_hand()

---@param user Entity
function card_init(user, props)
	return sword:create_action(user, function()
		local slash = create_slash("DEFAULT", user, props)
		Field.spawn(slash, user:current_tile())
	end)
end

function create_slash(animation_state, user, props)
	local spell = Spell.new(user:team())
	spell:set_texture(TEXTURE)
	spell:set_facing(user:facing())
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Flinch,
			Element.Sword,
			user:context(),
			Drag.None
		)
	)
	local anim = spell:animation()
	anim:load(ANIMATION_PATH)
	anim:set_state(animation_state)
	spell:animation():on_complete(function()
		spell:erase()
	end)

	spell.on_update_func = function()
		local directions = {
			Direction.UpLeft, Direction.Up, Direction.UpRight,
			Direction.Left, Direction.Right,
			Direction.DownLeft, Direction.Down, Direction.DownRight,
		}

		for _, direction in ipairs(directions) do
			local tile = spell:get_tile(direction, 1)

			if tile then
				tile:set_highlight(Highlight.Flash)
				spell:attack_tile(tile)
			end
		end
	end

	Resources.play_audio(AUDIO)

	return spell
end
