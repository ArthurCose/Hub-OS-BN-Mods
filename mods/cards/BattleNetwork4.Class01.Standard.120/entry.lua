local START_SFX = Resources.load_audio("startingSound.ogg")
local END_SFX = Resources.load_audio("landingSound.ogg")
local TEXTURE = Resources.load_texture("slimer.png")

---@param user Entity
---@param props CardProperties
local function create_spell(user, props)
	local team = user:team()
	local direction = user:facing()

	local spell = Spell.new(team)
	spell:set_facing(direction)
	spell:set_texture(TEXTURE)
	spell:set_hit_props(
		HitProps.from_card(
			props,
			user:context(),
			Drag.None
		))
	local animation = spell:animation()
	animation:load("slimer.animation")
	animation:set_state("start")
	animation:set_playback(Playback.Loop)

	local SPEED = 8
	local y = -20 * 8
	animation:set_state("landing")

	spell.on_spawn_func = function()
		Resources.play_audio(START_SFX, AudioBehavior.NoOverlap)
	end
	animation:set_state("staying")

	spell.on_update_func = function()
		y = y + SPEED

		spell:set_offset(0, y)

		if y < 0 then
			return
		end

		spell.on_update_func = nil
		animation:set_state("leaving")
		animation:on_complete(function()
			spell:delete()
		end)

		spell:current_tile():set_team(team, direction)

		spell:attack_tile()

		Resources.play_audio(END_SFX, AudioBehavior.NoOverlap)
	end

	return spell
end

function card_init(user, props)
	local action = Action.new(user)
	action:set_lockout(ActionLockout.new_sequence())

	action.on_execute_func = function(self, user)
		-- the list of tiles we want to claim
		local tiles = {}

		-- resolve loop variables
		local x_start, x_end, x_step = 0, Field.width() - 1, 1

		if user:facing() == Direction.Left then
			-- flip loop direction
			x_start, x_end = x_end, x_start
			x_step = -x_step
		end

		-- looping y in reverse since we'll pop from the end of tiles later
		for y = Field.height() - 1, 0, -1 do
			for x = x_start, x_end, x_step do
				local tile = Field.tile_at(x, y)
				local is_valid =
					tile and
					tile:team() ~= user:team() and
					not tile:is_edge() and
					tile:facing() == user:facing_away()

				if is_valid then
					tiles[#tiles + 1] = tile
					break
				end
			end
		end

		local spawn_step = action:create_step()
		local next_spawn = 0
		spawn_step.on_update_func = function()
			if next_spawn > 0 then
				next_spawn = next_spawn - 1
				return
			end

			next_spawn = 30

			-- pop the last tile
			local tile = table.remove(tiles, #tiles)

			if not tile then
				-- no more tiles, we've waited for 30 extra frames here
				spawn_step:complete_step()
				return
			end

			local spell = create_spell(user, props)
			Field.spawn(spell, tile)
		end

		-- wait an extra 10 frames to allow animations to play
		local wait_step = action:create_step()
		local wait_time = 0
		wait_step.on_update_func = function()
			wait_time = wait_time + 1

			if wait_time > 10 then
				wait_step:complete_step()
			end
		end
	end

	return action
end
