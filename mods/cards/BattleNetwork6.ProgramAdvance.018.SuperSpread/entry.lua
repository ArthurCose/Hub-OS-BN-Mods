local bn_assets = require("BattleNetwork.Assets")

local BUSTER_TEXTURE = bn_assets.load_texture("BN6_WideShot_Buster.png")
local BUSTER_ANIM_PATH = bn_assets.fetch_animation_path("BN6_WideShot_Buster.animation")

local SHOT_TEXTURE = bn_assets.load_texture("WideShot.png")
local SHOT_ANIM_PATH = bn_assets.fetch_animation_path("WideShot.animation")

local AUDIO = bn_assets.load_audio("panelshot2.ogg")

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_SHOOT")

	local frame_times = { { 1, 2 }, { 1, 3 }, { 1, 2 }, { 1, 1 }, { 2, 3 }, { 3, 4 }, { 1, 6 },
		{ 2, 3 }, { 3, 4 }, { 1, 6 },
		{ 2, 3 }, { 4, 12 } }

	action:override_animation_frames(frame_times)
	action:set_lockout(ActionLockout.new_animation())

	action.on_execute_func = function(self, user)
		user:set_counterable(true)

		local buster = self:create_attachment("BUSTER")
		buster:sprite():set_texture(BUSTER_TEXTURE)
		buster:sprite():set_layer(-1)

		local buster_anim = buster:animation()
		buster_anim:load(BUSTER_ANIM_PATH)

		buster_anim:set_state("SuprSpr", frame_times)

		buster_anim:on_frame(5, function()
			user:set_counterable(false)

			local shot = create_wideshot(user, props, false)

			local tile = user:get_tile(user:facing(), 1)

			Field.spawn(shot, tile)
		end)

		buster_anim:on_frame(8, function()
			local shot = create_wideshot(user, props, false)

			local tile = user:get_tile(user:facing(), 1)

			Field.spawn(shot, tile)
		end)

		buster_anim:on_frame(11, function()
			local shot = create_wideshot(user, props, true)

			local tile = user:get_tile(user:facing(), 1)

			Field.spawn(shot, tile)
		end)
	end
	return action
end

function create_wideshot(user, props, is_last)
	local spell = Spell.new(user:team())

	local flags = props.hit_flags

	if is_last == true then
		flags = flags | Hit.Flash
	end

	spell:set_facing(user:facing())
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			flags,
			props.element,
			user:context(),
			Drag.None
		)
	)

	local attacking = false

	local anim = spell:animation()
	spell:set_texture(SHOT_TEXTURE)

	spell._can_move_yet = false

	local buster_point = user:animation():get_point("BUSTER")
	local origin = user:sprite():origin()
	local fire_x = buster_point.x - origin.x + (21 - user:current_tile():width())
	local fire_y = buster_point.y - origin.y

	spell:set_offset(fire_x, fire_y)

	anim:load(SHOT_ANIM_PATH)
	anim:set_state("SPAWN")
	anim:set_playback(Playback.Once)
	anim:on_complete(function()
		-- Allowed to attack
		attacking = true

		-- Allowed to move
		spell._can_move_yet = true

		anim:set_state("LOOP")
		anim:set_playback(Playback.Loop)
	end)

	local move_speed_table = { 4, 6, 7, 6 }
	local move_index = 1

	spell.on_update_func = function(self)
		if not attacking then return end

		local tile = self:current_tile()
		local tiles = {
			tile,
			tile:get_tile(Direction.Up, 1),
			tile:get_tile(Direction.Down, 1),
		}

		self:attack_tiles(tiles)

		for index, value in ipairs(tiles) do
			value:set_highlight(Highlight.Flash)
		end

		if self:is_sliding() == false and spell._can_move_yet == true then
			if tile:is_edge() then self:delete() end

			local dest = self:get_tile(spell:facing(), 1)

			self:slide(dest, move_speed_table[move_index], function()
				move_index = math.min(4, move_index + 1)
			end)
		end
	end

	spell.on_delete_func = function(self)
		self:erase()
	end

	spell.can_move_to_func = function(tile)
		return spell._can_move_yet
	end

	spell.on_spawn_func = function()
		Resources.play_audio(AUDIO)
	end

	return spell
end
