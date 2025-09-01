local bn_assets = require("BattleNetwork.Assets")

local NAVI_TEXTURE = bn_assets.load_texture("navi_blastman.png")
local NAVI_ANIM_PATH = bn_assets.fetch_animation_path("navi_blastman.animation")

local ATTACK_AUDIO = bn_assets.load_audio("firehit4.ogg")

---@param actor Entity
---@param props CardProperties
function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_MOVE")

	action:override_animation_frames({ { 1, 2 }, { 2, 2 }, { 3, 2 } })

	action:set_lockout(ActionLockout.new_sequence())
	action:create_step()

	local end_timer = 28 + (6 * Field.width())

	local function attempt_fireball(tile)
		local facing = Direction.Right
		local end_x = Field.width()

		if tile:x() > 0 then
			facing = Direction.Left
			end_x = 0
		end

		local check_tile = tile:get_tile(facing, 1)

		if not check_tile then return end
		if check_tile:is_edge() then return end

		local fireball = Spell.new(actor:team())
		fireball:set_hit_props(
			HitProps.from_card(props, actor:context())
		)

		fireball:set_texture(NAVI_TEXTURE)

		fireball.can_move_to_func = function()
			return true
		end

		local spell_anim = fireball:animation()
		spell_anim:load(NAVI_ANIM_PATH)
		spell_anim:set_state("FLARE_BOMB_HORI")
		spell_anim:set_playback(Playback.Loop)

		fireball.on_update_func = function(self)
			if not self:is_sliding() then
				if self:current_tile():x() >= end_x then
					self:erase()
					return
				end

				self:slide(self:current_tile():get_tile(facing, 1), 6)
			end

			self:attack_tile()
		end

		fireball.on_collision_func = function(self, other)
			local other_sprite = other:sprite()
			local width = other_sprite:width()
			local height = other_sprite:height()

			local hit_effect = bn_assets.HitParticle.new("FIRE",
				(math.random(-50, 50) / 100) * width,
				(math.random(-50, 50) / 100) * height
			)

			fireball.can_move_to_func = function()
				return false
			end

			Field.spawn(hit_effect, self:current_tile())

			self:erase()
		end

		Field.spawn(fireball, tile)
	end

	---@type Entity
	local navi
	---@type Animation
	local navi_animation

	action.on_execute_func = function(self, user)
		action:add_anim_action(3, function()
			actor:hide()
		end)

		local direction = actor:facing()
		local start_x = 0

		if user:team() == Team.Blue or (user:team() == Team.Other and direction == Direction.Left) then
			start_x = Field.width()
		end

		-- Setup the navi's sprite and animation.
		-- Done separately from the actual state and texture assignments for a reason.
		-- We need this to be accessible by other local functions down below.
		navi = Artifact.new(actor:team())

		local navi_sprite = navi:sprite()
		navi_animation = navi:animation()

		navi:set_facing(direction)
		navi_sprite:set_texture(NAVI_TEXTURE)
		navi_animation:load(NAVI_ANIM_PATH)

		-- Spawn navi using movement state
		navi_animation:set_state("CHARACTER_MOVE", { { 3, 2 }, { 2, 2 }, { 1, 2 } })

		-- Only once, no looping necessary
		navi_animation:set_playback(Playback.Once)

		-- On complete, change his animation state

		local spawn_tile = user:current_tile()
		navi_animation:on_complete(function()
			navi_animation:set_state("CHARACTER_FIRE_START")

			navi_animation:set_playback(Playback.Once)

			navi_animation:on_complete(function()
				navi_animation:set_state("CHARACTER_FIRE_HORI_LOOP")

				navi_animation:set_playback(Playback.Loop)

				navi_animation:on_frame(2, function()
					Resources.play_audio(ATTACK_AUDIO)
					for y = -1, 1, 1 do
						attempt_fireball(Field.tile_at(start_x, spawn_tile:y() + y))
					end
				end, true)
			end)
		end)

		Field.spawn(navi, spawn_tile)
	end

	action.on_update_func = function()
		end_timer = end_timer - 1

		if end_timer == 0 then
			navi_animation:set_state("CHARACTER_MOVE", { { 1, 2 }, { 2, 2 }, { 3, 2 } })
			navi_animation:on_complete(function()
				if navi and not navi:deleted() then
					-- Erase the navi
					navi:erase()
				end

				actor:reveal()
				action:end_action()
			end)
		end
	end

	return action
end
