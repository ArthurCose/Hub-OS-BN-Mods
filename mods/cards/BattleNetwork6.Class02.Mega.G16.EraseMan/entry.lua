local bn_assets = require("BattleNetwork.Assets")

local ERASE_BEAM_TEXTURE = bn_assets.load_texture("erase_beam.png")
local ERASE_BEAM_ANIM_PATH = bn_assets.fetch_animation_path("erase_beam.animation")

local DOT_TEXTURE = bn_assets.load_texture("erase_beam_dot.png")
local DOT_ANIM_PATH = bn_assets.fetch_animation_path("erase_beam_dot.animation")

local NAVI_TEXTURE = bn_assets.load_texture("eraseman.png")
local NAVI_ANIM_PATH = bn_assets.fetch_animation_path("eraseman.animation")

local DOT_AUDIO = bn_assets.load_audio("magnum_cursor.ogg")
local ATTACK_AUDIO = bn_assets.load_audio("shock.ogg")


function card_init(actor, props)
	local action = Action.new(actor)
	action:set_lockout(ActionLockout.new_sequence())

	local step = action:create_step()

	-- Don't start overall timer or direction timer until we actually do stuff, or it'll come out funny
	local timer_start = false

	-- This is for finishing the attack and ending the action.
	local begin_countdown = false

	-- Overall timer, chip will execute without input after this many frames
	local timer = 360

	-- Setup EraseMan's sprite and animation.
	-- Done separately from the actual state and texture assignments for a reason.
	-- We need this to be accessible by other local functions down below.
	local navi = Artifact.new(actor:team())
	local navi_sprite = navi:sprite()
	local navi_animation = navi:animation()

	-- Timer between direction shifts, depends on navi chip version
	local direction_change_timer;
	if props.short_name == "ErasMnEX" then
		direction_change_timer = 16
	elseif props.short_name == "ErasMnSP" then
		direction_change_timer = 12
	else
		direction_change_timer = 20
	end

	-- How long to let the beam animation play out before EraseMan vanishes
	local endlag = 60

	-- Separate from timer for comparison's sake
	local change_time_counter = 0

	local direction = actor:facing()
	local up_direction = Direction.join(direction, Direction.Up)
	local down_direction = Direction.join(direction, Direction.Down)

	local tile = actor:current_tile()

	local forward_list = {}
	local up_list = {}
	local down_list = {}
	local current_list = nil

	local function populate_direction_list(dir, list)
		local x = 1
		-- This is normally dangerous
		-- This is a guaranteed infinite loop, but I'm using it with caution and for a reason
		-- I need to continually increment in one of three unknowable directions until I hit an edge tile.
		while true do
			-- So, assign the tile to check
			local check_tile = tile:get_tile(dir, x)

			-- If the tile is nonexisting, OR if it IS existing BUT is an edge tile, then break the loop off.
			if check_tile == nil or check_tile ~= nil and check_tile:is_edge() then
				break
			else
				-- Otherwise, insert the tile into the list.
				table.insert(list, check_tile)
			end

			x = x + 1
		end

		-- Return the list for assignment.
		return list
	end

	-- Creation depends on if we're dotting or shooting.
	local create_dot = function(is_attack)
		local dot = Spell.new(actor:team())
		dot:set_facing(actor:facing())
		local dot_sprite = dot:sprite()

		dot_sprite:set_layer(-20)

		local dot_animation = dot:animation()

		if is_attack == false then
			dot_sprite:set_texture(DOT_TEXTURE)

			dot_animation:load(DOT_ANIM_PATH)

			dot_animation:set_state("DEFAULT")

			dot._despawn_timer = direction_change_timer
			dot.on_update_func = function(self)
				self._despawn_timer = self._despawn_timer - 1
				if self._despawn_timer == 0 or actor:input_has(Input.Pressed.Use) then self:erase() end
			end

			-- Play the appropriate sound. In this case, the dot's beep noise.
			Resources.play_audio(DOT_AUDIO)
		else
			-- Set texture and animation path as usual
			dot_sprite:set_texture(ERASE_BEAM_TEXTURE)
			dot_animation:load(ERASE_BEAM_ANIM_PATH)

			dot:set_elevation(40)

			-- Set up the damage and hit properties
			dot:set_hit_props(
			-- HitProps.from_card fetches the appropriate values from the props passed in to card_init.
			-- You can take advantage of this in other ways using CardProperties.from_package or Player.deck_card_properties, depending on the situation.
			-- Any valid CardProperties will work for this, you know?
				HitProps.from_card(
					props,
					actor:context(),
					Drag.None
				)
			)

			-- State of the beam depends on current list used
			local DIRECTIONAL_STATE
			if current_list == up_list then
				DIRECTIONAL_STATE = "UP"
			elseif current_list == down_list then
				DIRECTIONAL_STATE = "DOWN"
			else
				DIRECTIONAL_STATE = "FORWARD"
			end

			-- Set the state depending on the outcome
			dot_animation:set_state(DIRECTIONAL_STATE)

			dot_animation:set_playback(Playback.Loop)

			-- Attack using the update func
			dot.on_update_func = function(self)
				if navi_animation:state() == "MOVE_START" then
					self:erase()
					return
				end

				self:attack_tile()
			end

			-- Play the appropriate sound. In this case, the attack noise.
			Resources.play_audio(ATTACK_AUDIO)
		end


		return dot
	end

	-- Spawning the dots.
	-- Or the electric beam attack, if we're attacking.
	local function spawn_dots(is_attack)
		-- Do nothing if the direction is not set.
		if current_list == nil then return end

		if is_attack == true then navi_animation:set_state("ERASE_BEAM_FIRE") end

		for i = 1, #current_list, 1 do
			local dot = create_dot(is_attack)

			Field.spawn(dot, current_list[i])
		end
	end

	-- Populate the lists.
	-- The Up and Down lists only get populated if they're valid directions.
	-- This simulates EraseMan not wasting his time with directions where there aren't any victims.
	if not tile:get_tile(Direction.Up, 1):is_edge() then
		up_list = populate_direction_list(up_direction, up_list)
	end

	forward_list = populate_direction_list(direction, forward_list)

	if not tile:get_tile(Direction.Down, 1):is_edge() then
		down_list = populate_direction_list(down_direction, down_list)
	end

	-- Store them as options
	local options = { up_list, forward_list, down_list }
	local options_index = 1

	-- Direction changes on a separate timer from the overall
	-- This function controls that mechanic
	local function check_direction()
		if current_list == nil then
			local i = 1

			while current_list == nil and i < #options do
				if #options[i] > 0 then
					current_list = options[i]
					options_index = i
					break
				end

				-- Increment the variable, or you'll softlock with an infinite loop sometimes
				-- While loops do not increment for you, unlike For loops.
				i = i + 1
			end
		else
			if options_index == #options then
				options_index = 1
			else
				options_index = options_index + 1
			end

			current_list = options[options_index]

			-- Redundant? Certainly.
			-- Safe, though? Absolutely.
			while #current_list == 0 do
				if options_index == #options then
					options_index = 1
				else
					options_index = options_index + 1
				end

				current_list = options[options_index]
			end
		end

		-- Since we're using this function to alter the direction,
		-- don't bother setting it to attack.
		spawn_dots(false)
	end

	navi_sprite:set_texture(NAVI_TEXTURE)
	navi_animation:load(NAVI_ANIM_PATH)

	-- Spawn EraseMan in by repurposing his movement
	navi_animation:set_state("MOVE_FINISH")

	-- Only once, no looping necessary
	navi_animation:set_playback(Playback.Once)

	-- On complete, change his animation state
	navi_animation:on_complete(function()
		navi_animation:set_state("ERASE_BEAM_START")

		-- Again, once, no looping necessary
		navi_animation:set_playback(Playback.Once)

		-- Yet again change the completion to allow the timer to start and check the beam direction
		navi_animation:on_complete(function()
			timer_start = true

			-- Since the list starts out undefined, it'll find the first good list to work with.
			check_direction()
		end)
	end)

	action.on_execute_func = function(self, user)
		user:hide()
		Field.spawn(navi, user:current_tile())
	end


	action.on_update_func = function()
		if begin_countdown == true then
			endlag = endlag - 1
			if endlag == 0 then
				navi_animation:set_state("MOVE_START")
				navi_animation:on_complete(function()
					-- Erase the navi
					navi:erase()

					-- Reveal the player again
					actor:reveal()

					-- And end the action.
					action:end_action()
				end)
			end
		end

		-- Do nothing if we have not spawned the Erase Beam dots yet.
		if timer_start == false then return end

		timer = timer - 1

		change_time_counter = change_time_counter + 1

		if change_time_counter == direction_change_timer then
			check_direction()

			-- Reset the counter
			change_time_counter = 0
		end

		if actor:input_has(Input.Pressed.Use) then
			-- Skip direction check and go directly to spawning
			-- Pass in true for the parameter to ensure we attack this time
			spawn_dots(true)

			-- Stop the timer, we're finishing up anyway
			timer_start = false
			begin_countdown = true
		end
	end

	return action
end
