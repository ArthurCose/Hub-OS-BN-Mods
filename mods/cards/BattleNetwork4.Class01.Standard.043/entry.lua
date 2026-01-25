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

local enemy_superArmor = false
function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_SHOOT")
	action:override_animation_frames(FRAMES)
	action:set_lockout(ActionLockout.new_animation())
	action.on_execute_func = function(self, user)
		local numBugs = 0
		for _, augment in ipairs(user:augments()) do
			if not augment:deleted() and augment:has_tag("BUG") then
				numBugs = numBugs + 1
			end
		end



		local result_or_err = pcall(function()
			-- This is the code being 'tried'
			local super_armor = AuxProp.new():declare_immunity(Hit.Flinch)
			user:remove_aux_prop(super_armor)
		end)

		-- 'Catch' block: check the success status

		local buster = self:create_attachment("BUSTER")
		buster:sprite():set_texture(BUSTER_TEXTURE)
		buster:sprite():set_layer(-1)
		buster:sprite():use_root_shader()
		self:on_anim_frame(1, function()
			user:set_counterable(true)
		end)
		local buster_anim = buster:animation()
		buster_anim:load(BUSTER_ANIM_PATH)
		buster_anim:set_state("DEFAULT_STATIC")
		buster_anim:apply(buster:sprite())
		buster_anim.on_complete = function()
			buster_anim:set_state("STATIC_LOOP")
			buster_anim:set_playback(Playback.Loop)
		end
		self:on_anim_frame(4, function()
			user:set_counterable(false)
			local tile = user:get_tile(user:facing(), 2)
			local initial_tile_x = tile:x()
			local initial_tile_y = tile:y()
			local onebug = tile:get_tile(user:facing(), 1)

			local twoBug_first = tile:get_tile(Direction.Up, 1)
			local twoBug_Second = tile:get_tile(Direction.Down, 1)
			local threeBug_first = tile:get_tile(user:facing(), 1):get_tile(Direction.Up, 1)
			local threeBug_Second = tile:get_tile(user:facing(), 1):get_tile(Direction.Down, 1)

			if tile then
				create_attack(user, props, tile)

				if numBugs >= 1 then
					create_attack(user, props, onebug)
				end
				if numBugs >= 2 then
					create_attack(user, props, twoBug_first)
					create_attack(user, props, twoBug_Second)
				end
				if numBugs >= 3 then
					create_attack(user, props, threeBug_first)
					create_attack(user, props, threeBug_Second)
				end
				Resources.play_audio(AUDIO)
			end
		end)
	end
	return action
end

function create_attack(user, props, spawn_tile)
	if spawn_tile:is_edge() then
		return
	end

	local spell = Spell.new(user:team())

	local hits = 8
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
			anim:set_state("DARK")



			spell:set_hit_props(hit_props)
			anim:apply(spell:sprite())

			anim:set_playback(Playback.Loop)

			anim:on_complete(function()
				if hits > 1 then
					hits = hits - 1
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

	spell.on_delete_func = function(self)
		self:erase()
	end

	-- Tornado cannot move. It only spawns.
	spell.can_move_to_func = function(tile) return false end



	Field.spawn(spell, spawn_tile)
end
