---@type dev.konstinople.library.sword
local SwordLib = require("dev.konstinople.library.sword")

local bn_assets = require("BattleNetwork.Assets")

local TEXTURE = bn_assets.load_texture("BlizzBall.png")
local TEXTURE_ANIM = bn_assets.fetch_animation_path("BlizzBall.animation")

local LAUNCH_AUDIO = bn_assets.load_audio("bees.ogg")
local ABSORB_AUDIO = bn_assets.load_audio("trash_chute.ogg")

local sword = SwordLib.new_sword()
sword:use_hand()
sword:set_frame_data({ { 1, 2 }, { 2, 2 }, { 3, 2 }, { 4, 999 } })

function card_init(user, props)
	local blizzard_ball;
	local action = sword:create_action(user, function()
		local dir = user:facing()
		local tile = user:get_tile(dir, 1)

		if not tile then return end

		blizzard_ball = create_blizzard_ball(user, props)

		Field.spawn(blizzard_ball, tile)
	end)

	local step = action:create_step()
	step.on_update_func = function()
		if blizzard_ball == nil then return end
		if blizzard_ball:deleted() or blizzard_ball:will_erase_eof() then
			step:complete_step()
			return
		end
	end

	action:set_lockout(ActionLockout.new_sequence())

	return action
end

function create_blizzard_ball(user, props)
	local spell = Spell.new(user:team())

	local direction = user:facing()

	local base_damage = props.damage
	local multiplier = 1

	local anim = spell:animation()
	anim:load(TEXTURE_ANIM)
	anim:set_state("DEFAULT")

	local sprite = spell:sprite()
	sprite:set_texture(TEXTURE)

	anim:set_playback(Playback.Loop)

	spell:set_hit_props(HitProps.from_card(props, user:context(), Drag.None))

	spell.on_update_func = function(self)
		local tile = self:current_tile()

		if self._delete_counter ~= nil then
			if self._delete_counter == 0 then self:delete() end
			self._delete_counter = self._delete_counter - 1
			return
		end

		if not tile then
			self:delete()
			return
		end


		if not tile:is_walkable() then
			self:delete()
			return
		end

		tile:attack_entities(self)

		if not self:is_sliding() then
			local dest = self:get_tile(direction, 1)

			if not dest then
				self._delete_counter = true
				return
			end

			if dest then
				self:slide(dest, 12, function()
					if not dest:is_walkable() then
						self._delete_counter = 6
					end
				end)
			end
		end
	end

	spell.on_collision_func = function(self, other)
		if Obstacle.from(other) ~= nil then
			if anim:state() ~= "BIG" then
				anim:set_state("BIG")
				anim:set_playback(Playback.Loop)
			end

			other:erase()
			multiplier = multiplier + 1

			props.damage = base_damage * multiplier

			self:set_hit_props(HitProps.from_card(props, user:context(), Drag.None))

			Resources.play_audio(ABSORB_AUDIO)
		else
			local fx = bn_assets.HitParticle.new("AQUA")

			Field.spawn(fx, spell:current_tile())
		end
	end

	spell.on_delete_func = function(self)
		self:erase()
	end

	spell.can_move_to_func = function(tile)
		-- Can't move to tiles that don't exist
		if not tile then return false end

		return true
	end

	Resources.play_audio(LAUNCH_AUDIO)

	return spell
end
