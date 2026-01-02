local bn_assets = require("BattleNetwork.Assets")
local TEXTURE = bn_assets.load_texture("bn3_lightning.png")
local ANIM_PATH = bn_assets.fetch_animation_path("bn3_lightning.animation")
local FLASH_TEXTURE = bn_assets.load_texture("flashlight.png")
local FLASH_ANIM_PATH = bn_assets.fetch_animation_path("flashlight.animation")
local AUDIO = bn_assets.load_audio("dollthunder.ogg")

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_HIT")
	local long_frame = { { 2, 1 }, { 2, 18 }, { 2, 26 } }
	action:override_animation_frames(long_frame)

	action:set_lockout(ActionLockout.new_animation())

	action.on_execute_func = function(self, user)
		local flash = Artifact.new()
		flash:set_texture(FLASH_TEXTURE)
		flash:animation():load(FLASH_ANIM_PATH)
		flash:animation():set_state("DEFAULT")
		flash:animation():on_complete(function()
			flash:erase()
		end)

		flash:sprite():set_scale(8, 8)

		local flash_color_component = flash:create_component(Lifetime.ActiveBattle)
		flash_color_component.on_update_func = function(self)
			local sprite = self:owner():sprite()
			local color = sprite:color()
			color.a = 128
			sprite:set_color(color)
			sprite:set_color_mode(ColorMode.Additive)
		end

		Field.spawn(flash, Field.tile_at(1, 1))

		local targets = Field.find_obstacles(function(found)
			if not found:hittable() then return false end
			if found:team() == user:team() then return false end
			return true
		end)

		self:on_anim_frame(2, function()
			local tile = nil

			for i = 1, #targets, 1 do
				tile = targets[i]:current_tile()
				local tiles = { tile }
				local tile_x = tile:x()
				local tile_y = tile:y()

				for x = -1, 1, 1 do
					for y = -1, 1, 1 do
						table.insert(tiles, Field.tile_at(tile_x + x, tile_y + y))
					end
				end

				create_bolt(user, props, tiles)
			end
		end)
	end
	return action
end

function create_bolt(user, props, tiles)
	local spell = Spell.new(user:team())

	spell:set_facing(user:facing())
	spell:set_tile_highlight(Highlight.Solid)
	spell:set_hit_props(HitProps.from_card(props, user:context(), Drag.None))
	local anim = spell:animation()
	spell:set_texture(TEXTURE)

	anim:load(ANIM_PATH)
	anim:set_state("DEFAULT")

	anim:apply(spell:sprite())
	anim:on_complete(function()
		spell:erase()
	end)


	spell.on_update_func = function(self)
		self:attack_tiles(tiles)
	end

	spell.can_move_to_func = function(tile)
		return true
	end

	Resources.play_audio(AUDIO)

	Field.spawn(spell, tiles[1])
end
