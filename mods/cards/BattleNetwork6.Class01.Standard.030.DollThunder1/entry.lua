local bn_assets = require("BattleNetwork.Assets")

local SPELL_TEXTURE = bn_assets.load_texture("thunderbolt.png")
local SPELL_ANIM_PATH = bn_assets.fetch_animation_path("thunderbolt.animation")

local BUSTER_TEXTURE = bn_assets.load_texture("doll_thunder.png")
local BUSTER_ANIM_PATH = bn_assets.fetch_animation_path("doll_thunder.animation")

local THUNDER_AUDIO = bn_assets.load_audio("shock.ogg")

local function create_thunderbolt(user, props)
	local spell = Spell.new(user:team())

	local facing = user:facing()

	spell:set_facing(facing)

	spell:set_hit_props(HitProps.from_card(props))

	spell:set_texture(SPELL_TEXTURE)

	spell:sprite():set_layer(-3)

	local spell_anim = spell:animation()
	spell_anim:load(SPELL_ANIM_PATH)

	spell_anim:set_state("DEFAULT")
	spell_anim:set_playback(Playback.Loop)

	local buster_point = user:animation():get_point("BUSTER")
	local origin = user:sprite():origin()
	local offset_x = buster_point.x - origin.x + 10
	local offset_y = buster_point.y - origin.y

	if facing == Direction.Left then
		offset_x = -offset_x
	end

	spell:set_offset(offset_x, offset_y)

	local tile_list = {
		user:get_tile(facing, 1),
		user:get_tile(facing, 2),
		user:get_tile(facing, 3),
		user:get_tile(facing, 4),
		user:get_tile(facing, 5)
	}

	local timer = 14

	spell.on_update_func = function()
		if timer == 0 then
			spell:delete()
			return
		end

		spell:attack_tiles(tile_list)

		timer = timer - 1
	end

	spell.on_delete_func = function()
		spell:erase()
	end

	Field.spawn(spell, user:current_tile())
end

function card_init(user, props)
	local action = Action.new(user, "CHARACTER_SHOOT")

	local frame_data = { { 1, 12 }, { 1, 1 }, { 1, 14 }, { 1, 5 } }

	action:override_animation_frames(frame_data)

	action:set_lockout(ActionLockout.new_animation())

	-- setup buster attachment
	local buster_attachment = action:create_attachment("BUSTER")
	local buster_sprite = buster_attachment:sprite()
	local buster_animation = buster_attachment:animation()

	action:on_anim_frame(1, function()
		buster_sprite:set_texture(BUSTER_TEXTURE)

		buster_sprite:set_layer(-2)
		buster_sprite:use_root_shader()

		buster_animation:load(BUSTER_ANIM_PATH)

		buster_animation:set_state("DEFAULT")
		user:set_counterable(true)
	end)

	action:on_anim_frame(2, function()
		user:set_counterable(false)

		buster_animation:set_state("ACTIVE")
		buster_animation:set_playback(Playback.Loop)

		create_thunderbolt(user, props)

		Resources.play_audio(THUNDER_AUDIO)
	end)

	return action
end
