local bn_assets = require("BattleNetwork.Assets")

local BUSTER_TEXTURE = bn_assets.load_texture("BN6_WideShot_Buster.png")
local BUSTER_ANIM_PATH = bn_assets.fetch_animation_path("BN6_WideShot_Buster.animation")

local SHOT_TEXTURE = bn_assets.load_texture("WideShot.png")
local SHOT_ANIM_PATH = bn_assets.fetch_animation_path("WideShot.animation")

local AUDIO = bn_assets.load_audio("panelshot2.ogg")

function card_mutate(user, index)
	if Player.from(user) == nil then return end
	user:boost_augment("dev.GladeWoodsgrove.Bugs.PowerJam", 1)
end

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_SHOOT")

	local frame_times = { { 1, 26 } }

	action:override_animation_frames(frame_times)
	action:set_lockout(ActionLockout.new_animation())

	action.on_execute_func = function(self, user)
		user:set_counterable(true)

		local buster = self:create_attachment("BUSTER")
		buster:sprite():set_texture(BUSTER_TEXTURE)
		buster:sprite():set_layer(-1)

		local buster_anim = buster:animation()
		buster_anim:load(BUSTER_ANIM_PATH)

		buster_anim:set_state("DARK")

		buster_anim:on_frame(3, function()
			user:set_counterable(false)

			local shot = create_wideshot(user, props)

			local tile = user:get_tile(user:facing(), 1)

			if tile then
				Field.spawn(shot, tile)
			end
		end)
	end
	return action
end

function create_wideshot(user, props)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_hit_props(
		HitProps.from_card(
			props,
			user:context(),
			Drag.None
		)
	)

	local attacking = false

	local anim = spell:animation()
	spell:set_texture(SHOT_TEXTURE)

	local buster_point = user:animation():get_point("BUSTER")
	local origin = user:sprite():origin()
	local fire_x = buster_point.x - origin.x + (21 - user:current_tile():width())
	local fire_y = buster_point.y - origin.y

	spell:set_offset(fire_x, fire_y)

	anim:load(SHOT_ANIM_PATH)
	anim:set_state("SPAWN_DARK")
	anim:set_playback(Playback.Once)
	anim:on_complete(function()
		-- Allowed to attack
		attacking = true

		anim:set_state("LOOP_DARK")
		anim:set_playback(Playback.Loop)
	end)

	local move_speed_table = { 6, 6, 7, 6 }
	local move_index = 1

	local function create_shadow()
		local shadow = Spell.new(user:team())
		shadow:set_texture(SHOT_TEXTURE)

		local shadow_anim = shadow:animation()
		shadow_anim:load(SHOT_ANIM_PATH)
		shadow_anim:set_state("SHADOW")
		shadow_anim:set_playback(Playback.Loop)

		shadow:set_offset(fire_x, fire_y)

		shadow:set_facing(user:facing())

		local timer = 12
		shadow.on_update_func = function(self)
			if timer <= 0 then
				self:erase()
				return
			end

			if timer % 2 then
				self:sprite():set_visible(not self:sprite():visible())
			end

			timer = timer - 1
		end

		return shadow
	end


	spell.on_update_func = function(self)
		if not attacking then return end

		local tile = self:current_tile()

		if tile:is_edge() then
			self:delete()
			return
		end

		self:attack_tiles(
			{
				tile,
				tile:get_tile(Direction.Up, 1),
				tile:get_tile(Direction.Down, 1),
			}
		)

		if not self:is_moving() then
			local dest = self:get_tile(spell:facing(), 1)

			self:slide(dest, move_speed_table[move_index], function()
				Field.spawn(create_shadow(), tile)
				move_index = math.min(4, move_index + 1)
			end)
		end
	end

	spell.on_spawn_func = function()
		Resources.play_audio(AUDIO)
	end

	return spell
end
