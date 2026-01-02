local function includes(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end

	return false
end

---@type BattleNetwork6.Libraries.PanelGrab
local PanelGrabLib = require("BattleNetwork6.Libraries.PanelGrab")

---@type BattleNetwork6.Libraries.ChipNavi
local ChipNaviLib = require("BattleNetwork6.Libraries.ChipNavi")

---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local NAVI_TEXTURE = bn_assets.load_texture("navi_flashman.png")
local NAVI_ANIM_PATH = bn_assets.fetch_animation_path("navi_flashman.animation")

local ATTACK_AUDIO = bn_assets.load_audio("shock.ogg")
local SPAWN_AUDIO = bn_assets.load_audio("appear.ogg")
local MOVE_AUDIO = bn_assets.load_audio("physical_projectile.ogg")

local function grab_tiles(user, start_y, goal_y)
	local team = user:team()
	local direction = user:facing()

	local x = user:current_tile():x()
	local found_opponent_panels = false

	local test_offset = 1

	if direction == Direction.Left then
		test_offset = -1
	end

	-- find opponent panels ahead of us
	while not found_opponent_panels do
		x = x + test_offset

		for y = start_y, goal_y do
			local tile = Field.tile_at(x, y)

			if not tile then
				-- reached out of bounds, give up
				return
			end

			if tile:team() ~= team and not tile:is_edge() then
				found_opponent_panels = true
				break
			end
		end
	end

	-- rewind to find area we've fully claimed, in case we're surrounded by opponent tiles
	while true do
		x = x - test_offset

		local has_opponent_panels = false

		for y = start_y, goal_y do
			local tile = Field.tile_at(x, y)

			if not tile then
				-- reached out of bounds, give up
				return
			end

			if tile:team() ~= team and not tile:is_edge() then
				has_opponent_panels = true
				break
			end
		end

		if not has_opponent_panels then
			-- no opponent panels in the column!
			break
		end
	end

	-- step forward once to get out of the area fully claimed by us
	x = x + test_offset

	-- spawn panel grab at every tile in the column
	for y = start_y, goal_y do
		local tile = Field.tile_at(x, y)

		if tile and not tile:is_edge() then
			local spell = PanelGrabLib.create_spell(team, direction)
			Field.spawn(spell, tile)
		end
	end
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
	local action = Action.new(user)
	action:set_lockout(ActionLockout.new_sequence())
	action:create_step()

	local end_timer = 40
	local grab_timer = 60
	local can_proceed = false
	local end_timer_started = false
	local spark_arm_spawned = false
	local grab_timer_started = false
	local spark_arm_loops_remaining = 4
	local previously_visible = user:sprite():visible()

	local start_y = user:current_tile():y()
	local goal_y = start_y
	if includes(props.tags, "GRAB_AREA") == true then
		start_y = 0
		goal_y = Field.height() - 1
	end

	---@type Entity
	local navi
	---@type Animation
	local navi_animation

	local function spawn_spark_arm()
		if spark_arm_spawned == true then return end

		local spark_arm = Spell.new(user:team())
		spark_arm:set_facing(user:facing())
		spark_arm:set_hit_props(
			HitProps.from_card(props, user:context())
		)

		spark_arm:set_texture(NAVI_TEXTURE)

		local spell_anim = spark_arm:animation()
		spell_anim:load(NAVI_ANIM_PATH)

		spell_anim:set_state("SPARK_ARM_ATTACK_SPAWN")
		spell_anim:set_playback(Playback.Once)
		spell_anim:on_complete(function()
			spell_anim:set_state("SPARK_ARM_ATTACK_LOOP")
			spell_anim:set_playback(Playback.Loop)

			spell_anim:on_complete(function()
				spark_arm_loops_remaining = spark_arm_loops_remaining - 1
			end)
		end)

		local facing = user:facing()
		local navi_tile = navi:current_tile()
		local tiles = {
			navi_tile:get_tile(facing, 1),
			navi_tile:get_tile(facing, 2),
			navi_tile:get_tile(Direction.join(Direction.Up, facing), 1),
			navi_tile:get_tile(Direction.join(Direction.Down, facing), 1)
		}

		spark_arm.on_update_func = function(self)
			if spark_arm_loops_remaining == 0 then
				self:delete()

				return
			end

			for i = 1, #tiles, 1 do
				if tiles[i] and tiles[i]:is_edge() == false then
					tiles[i]:set_highlight(Highlight.Solid)
				end
			end

			self:attack_tiles(tiles)
		end

		spark_arm.on_delete_func = function(self)
			end_timer_started = true

			navi_animation:set_state("SPARK_ARM_END")
			navi_animation:set_playback(Playback.Once)
			navi_animation:on_complete(function()
				navi_animation:set_state("CHARACTER_IDLE")
			end)

			for i = 1, #tiles, 1 do
				if tiles[i] and tiles[i]:is_edge() == false then
					tiles[i]:set_highlight(Highlight.None)
				end
			end

			self:erase()
		end

		spark_arm.on_collision_func = function(self, other)
			local other_sprite = other:sprite()
			local width = other_sprite:width()
			local height = other_sprite:height()

			local hit_effect = bn_assets.HitParticle.new("ELEC",
				(math.random(-50, 50) / 100) * width,
				(math.random(-50, 50) / 100) * height
			)

			spark_arm.can_move_to_func = function()
				return false
			end

			Field.spawn(hit_effect, other:current_tile())
		end

		spark_arm.on_spawn_func = function()
			Resources.play_audio(ATTACK_AUDIO)
		end

		Field.spawn(spark_arm, navi_tile:get_tile(facing, 1))
	end

	local occupied_query = function(e) return Obstacle.from(e) ~= nil or Character.from(e) ~= nil end

	action.on_execute_func = function(self, user)
		previously_visible = user:sprite():visible()
		local spawn_tile = user:current_tile()
		local jump_tile = user:current_tile()
		local direction = user:facing()
		local start_x = 0
		local increment = 1
		local goal_x = Field.width() - 1

		-- Setup the navi's sprite and animation.
		-- Done separately from the actual state and texture assignments for a reason.
		-- We need this to be accessible by other local functions down below.
		navi = Artifact.new(user:team())

		local navi_sprite = navi:sprite()
		navi_animation = navi:animation()

		navi:set_facing(direction)
		navi_sprite:set_texture(NAVI_TEXTURE)
		navi_animation:load(NAVI_ANIM_PATH)

		navi_animation:set_state("CHARACTER_IDLE")

		local do_once = true

		ChipNaviLib.swap_in(navi, user, function()
			grab_timer_started = true

			Resources.play_audio(SPAWN_AUDIO)

			navi_animation:set_state("CHARACTER_IDLE", { { 1, 30 } })

			navi_animation:on_complete(function()
				if do_once == true then
					for x = start_x, goal_x, increment do
						local check_tile = spawn_tile:get_tile(direction, x)
						if not check_tile then goto continue end
						if check_tile:is_walkable() == false then goto continue end
						if check_tile:team() ~= user:team() then goto continue end
						if check_tile:is_reserved() then goto continue end
						if #check_tile:find_entities(occupied_query) > 0 then goto continue end

						jump_tile = spawn_tile:get_tile(direction, x)

						::continue::
					end

					if jump_tile ~= spawn_tile then
						local artifact = bn_assets.MobMove.new("BIG_START")
						artifact:set_elevation(32)
						artifact:animation():on_frame(2, function()
							navi:hide()
							spawn_tile:remove_entity(navi)
							jump_tile:add_entity(navi)
						end)

						artifact:animation():on_complete(function()
							local artifact_2 = bn_assets.MobMove.new("BIG_END")
							artifact:set_elevation(32)

							artifact_2:animation():on_frame(2, function()
								navi:reveal()

								Resources.play_audio(MOVE_AUDIO)
							end)

							artifact_2:animation():on_complete(function()
								can_proceed = true

								artifact_2:erase()
							end)

							Field.spawn(artifact_2, jump_tile)

							artifact:erase()
						end)


						Field.spawn(artifact, spawn_tile)
					else
						can_proceed = true
					end

					do_once = false
				end
			end)
		end)

		Field.spawn(navi, spawn_tile)
	end

	action.on_update_func = function()
		if not grab_timer_started then return end

		if grab_timer == 60 then grab_tiles(user, start_y, goal_y) end

		grab_timer = grab_timer - 1

		if grab_timer > 0 then return end

		if can_proceed == true then
			navi_animation:set_state("CHARACTER_IDLE")
			navi_animation:set_playback(Playback.Once)

			navi_animation:on_complete(function()
				navi_animation:set_state("SPARK_ARM_START")

				navi_animation:on_complete(function()
					spawn_spark_arm()

					navi_animation:set_state("SPARK_ARM_LOOP")
					navi_animation:set_playback(Playback.Loop)

					spark_arm_spawned = true
				end)
			end)

			can_proceed = false
		end

		if not end_timer_started then return end

		end_timer = end_timer - 1

		if end_timer == 0 then
			ChipNaviLib.swap_in(user, navi, function()
				action:end_action()
			end)
		end
	end

	action.on_action_end_func = function()
		if previously_visible then
			user:reveal()
		else
			user:hide()
		end

		if navi and not navi:deleted() then
			navi:erase()
		end
	end

	return action
end
