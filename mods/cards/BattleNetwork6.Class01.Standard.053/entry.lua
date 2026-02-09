---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local AUDIO = bn_assets.load_audio("wind_burst.ogg")
local TEXTURE = bn_assets.load_texture("tornado_bn6.png")
local BUSTER_TEXTURE = bn_assets.load_texture("buster_fan.png")
local BUSTER_ANIM_PATH = bn_assets.fetch_animation_path("buster_fan.animation")
local SPELL_ANIM_PATH = bn_assets.fetch_animation_path("tornado_bn6.animation")

local FRAME1 = { 1, 6 }
local FRAME2 = { 2, 3 }
local FRAME3 = { 3, 3 }
local FRAMES = { FRAME1, FRAME3, FRAME2, FRAME3, FRAME2, FRAME3, FRAME2, FRAME3, FRAME2, FRAME3, FRAME2, FRAME1, FRAME3,
	FRAME2, FRAME3, FRAME2 }

local function includes(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end

	return false
end

local BOOST_STATES = {
	TileState.Grass or -1,
	TileState.Lava or -1,
	TileState.Ice or -1,
	TileState.Sand or -1,
	TileState.Magnet or -1,
	TileState.Volcano or -1
}

---@param user Entity
---@param props CardProperties
function create_attack(user, props)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_tile_highlight(Highlight.Solid)
	spell:set_texture(TEXTURE)
	spell:set_layer(-1)

	local anim = spell:animation()
	anim:load(SPELL_ANIM_PATH)
	anim:set_state("DEFAULT")
	anim:set_playback(Playback.Loop)

	spell.on_spawn_func = function()
		local hit_props = HitProps.from_card(
			props,
			user:context(),
			Drag.None
		)

		local cur_tile = spell:current_tile()

		if cur_tile and includes(BOOST_STATES, cur_tile:state()) then
			hit_props.damage = hit_props.damage + hit_props.damage
			cur_tile:set_state(TileState.Normal)
		end

		spell:set_hit_props(hit_props)

		local hits = 8
		anim:on_complete(function()
			if hits > 1 then
				hits = hits - 1
				local hitbox = Hitbox.new(spell:team())
				hitbox:set_hit_props(hit_props)
				Field.spawn(hitbox, spell:current_tile())
			else
				spell:erase()
			end
		end)
	end

	spell.on_update_func = function(self)
		self:current_tile():attack_entities(self)
	end

	Resources.play_audio(AUDIO)

	return spell
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
	local action = Action.new(user, "CHARACTER_SHOOT")
	action:override_animation_frames(FRAMES)
	action:set_lockout(ActionLockout.new_animation())

	action.on_execute_func = function(self, user)
		local buster = self:create_attachment("BUSTER")
		buster:sprite():set_texture(BUSTER_TEXTURE)
		buster:sprite():set_layer(-1)

		local buster_anim = buster:animation()
		buster_anim:load(BUSTER_ANIM_PATH)
		buster_anim:set_state("DEFAULT")
		buster_anim:apply(buster:sprite())
		buster_anim.on_complete = function()
			buster_anim:set_state("LOOP")
			buster_anim:set_playback(Playback.Loop)
		end
	end

	action:on_anim_frame(1, function()
		user:set_counterable(true)
	end)

	action:on_anim_frame(4, function()
		user:set_counterable(false)

		local tile = user:get_tile(user:facing(), 2)

		if tile then
			local spell = create_attack(user, props)
			Field.spawn(spell, tile)
		end
	end)

	action.on_action_end_func = function(self)
		user:set_counterable(false)
	end

	return action
end
