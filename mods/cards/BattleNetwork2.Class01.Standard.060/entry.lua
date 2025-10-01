---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local AUDIO = bn_assets.load_audio("wind_burst.ogg")
local TEXTURE = Resources.load_texture("twister.png")
local BUSTER_TEXTURE = bn_assets.load_texture("buster_fan.png")
local BUSTER_ANIM_PATH = bn_assets.fetch_animation_path("buster_fan.animation")
local SPELL_ANIM_PATH = bn_assets.fetch_animation_path("tornado_bn6.animation")

local FRAME1 = { 1, 6 }
local FRAME2 = { 2, 3 }
local FRAME3 = { 3, 3 }
local FRAMES = { FRAME1, FRAME3, FRAME2, FRAME3, FRAME2, FRAME3, FRAME2, FRAME3, FRAME2, FRAME3, FRAME2, FRAME1, FRAME3,
	FRAME2, FRAME3, FRAME2 }

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_SHOOT")
	action:override_animation_frames(FRAMES)
	action:set_lockout(ActionLockout.new_animation())
	action.on_execute_func = function(self, user)
		local buster = self:create_attachment("BUSTER")
		buster:sprite():set_texture(BUSTER_TEXTURE, true)
		buster:sprite():set_layer(-1)
		self:add_anim_action(1, function()
			user:set_counterable(true)
		end)
		local buster_anim = buster:animation()
		buster_anim:load(BUSTER_ANIM_PATH)
		buster_anim:set_state("DEFAULT")
		buster_anim:apply(buster:sprite())
		buster_anim.on_complete = function()
			buster_anim:set_state("LOOP")
			buster_anim:set_playback(Playback.Loop)
		end
		self:add_anim_action(4, function()
			user:set_counterable(false)
			local tile = user:get_tile(user:facing(), 2)
			if tile then
				local cannonshot = create_attack(user, props)
				Field.spawn(cannonshot, tile)
			end
		end)
	end
	return action
end

function create_attack(user, props)
	local spell = Spell.new(user:team())

	spell.hits = 4
	spell:set_facing(user:facing())
	spell:set_tile_highlight(Highlight.Solid)
	spell:set_texture(TEXTURE)
	spell:sprite():set_layer(-1)

	local hit_props = HitProps.from_card(
		props,
		user:context(),
		Drag.None
	)

	local do_once = true
	spell.on_update_func = function(self)
		if do_once then
			local anim = spell:animation()
			anim:load(SPELL_ANIM_PATH)
			anim:set_state("DEFAULT")

			local cur_tile = spell:current_tile()
			if cur_tile and cur_tile:state() == (TileState.Grass or TileState.Lava or TileState.Ice) then
				hit_props.damage = hit_props.damage + hit_props.damage
			end

			spell:set_hit_props(hit_props)
			anim:apply(spell:sprite())

			anim:set_playback(Playback.Loop)

			anim:on_complete(function()
				if spell.hits > 1 then
					spell.hits = spell.hits - 1
					local hitbox = Hitbox.new(spell:team())
					hitbox:set_hit_props(spell:copy_hit_props())
					Field.spawn(hitbox, spell:current_tile())
				else
					spell:erase()
				end
			end)
			do_once = false
		end
		self:current_tile():attack_entities(self)
	end

	spell.on_collision_func = function(self, other) end

	spell.on_attack_func = function(self, other) end

	spell.on_delete_func = function(self) self:erase() end

	-- Tornado cannot move. It only spawns.
	spell.can_move_to_func = function(tile) return false end

	Resources.play_audio(AUDIO)

	return spell
end
