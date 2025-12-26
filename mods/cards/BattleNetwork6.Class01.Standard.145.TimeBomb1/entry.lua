local bn_assets = require("BattleNetwork.Assets")

local bomb_texture = bn_assets.load_texture("bn6_timebomb.png")
local bomb_anim_path = bn_assets.fetch_animation_path("bn6_timebomb.animation")

local bomb_timer_audio = bn_assets.load_audio("timebomb1.ogg")
local bomb_ready_audio = bn_assets.load_audio("timebomb2.ogg")
local explosion_audio = bn_assets.load_audio("timebomb3.ogg")

local spawn_audio = bn_assets.load_audio("obstacle_spawn.ogg")

---@param user Entity
---@param tile Tile
local function is_dest_valid(user, tile)
	return not tile:is_reserved() and
			tile:is_walkable() and
			tile:team() ~= user:team()
end

---@param user Entity
local function find_dest(user)
	local ahead = user:get_tile(user:facing(), 1)

	while ahead do
		if is_dest_valid(user, ahead) then
			return ahead
		end

		ahead = ahead:get_tile(user:facing(), 1)
	end

	-- trying every row
	local start_x, end_x, inc_x = 0, Field.width(), 1
	local end_y = Field.height() - 1

	local function flip_range()
		start_x, end_x = end_x, start_x
		inc_x = -inc_x
	end

	if user:facing() == Direction.Left then
		-- flip the range to make sure we test the frontmost tiles first
		flip_range()
	end

	for x = start_x, end_x, inc_x do
		for y = 0, end_y do
			local tile = Field.tile_at(x, y)

			-- tile must be facing away to avoid placing behind when surrounded
			if tile and is_dest_valid(user, tile) and tile:facing() == user:facing_away() then
				return tile
			end
		end
	end

	-- test in the other direction in case we're surrounded or in multi-man
	-- we flip the range to target the frontmost tile
	flip_range()

	for x = start_x, end_x, inc_x do
		for y = 0, end_y do
			local tile = Field.tile_at(x, y)

			-- ignoring tile facing direction this time
			if tile and is_dest_valid(user, tile) then
				return tile
			end
		end
	end
end

function card_init(user, props)
	local action = Action.new(user)
	local step = action:create_step()

	action:set_lockout(ActionLockout.new_sequence())

	local time = 0

	step.on_update_func = function()
		time = time + 1
	end

	action.on_execute_func = function()
		local spawn_tile = find_dest(user)

		if not spawn_tile then
			action:end_action()
			return
		end

		local bomb = Obstacle.new(Team.Other)

		bomb:set_owner(user)

		bomb:add_aux_prop(AuxProp.new():declare_immunity(~Hit.Drag))
		bomb.can_move_to_func = function(tile)
			return tile:is_walkable()
		end

		local main_goal = false
		local bomb_health = 10

		local state_prefix = "TIMEBOMB_"
		if props.card_class == CardClass.Recipe then
			state_prefix = "GIGA_" .. state_prefix
			bomb_health = 200
		end

		bomb:set_health(bomb_health)

		local bomb_sprite = bomb:sprite()
		local bomb_animation = bomb:animation()

		bomb_sprite:set_texture(bomb_texture)
		bomb_sprite:set_never_flip(true)

		bomb_animation:load(bomb_anim_path)

		local countdown = bomb:create_node()
		countdown:set_texture(bomb_texture)
		countdown:set_never_flip(true)

		bomb_animation:set_state(state_prefix .. "SPAWN")

		local countdown_animator = Animation.new()
		countdown_animator:load(bomb_anim_path)
		countdown_animator:set_state("COUNTDOWN")
		countdown_animator:apply(countdown)

		local relative_offset = bomb_animation:relative_point("countdown")

		countdown:set_offset(relative_offset.x, relative_offset.y)
		countdown:hide()

		bomb_animation:on_complete(function()
			bomb_animation:set_state(state_prefix .. "IDLE")

			countdown:reveal()

			step:complete_step()

			action:set_lockout(ActionLockout.new_async(30))

			bomb:enable_hitbox(true)
		end)

		local function play_timebomb_sound(is_zero)
			if is_zero == true then
				Resources.play_audio(bomb_ready_audio)
			else
				Resources.play_audio(bomb_timer_audio)
			end
		end

		countdown_animator:on_frame(2, function()
			play_timebomb_sound(false)
		end, true)

		countdown_animator:on_frame(3, function()
			play_timebomb_sound(false)
		end, true)

		countdown_animator:on_frame(4, function()
			play_timebomb_sound(true)
		end, true)

		countdown_animator:on_complete(function()
			main_goal = true
		end)

		bomb.on_spawn_func = function()
			Resources.play_audio(spawn_audio)
		end

		local hit_props = HitProps.from_card(props)

		local spell_team = user:team()

		---@param tile Tile
		local function create_explosion_and_visual(tile)
			local tile_team = tile:team()
			if tile_team == spell_team then
				if Team.Red then
					spell_team = Team.Blue
				else
					spell_team = Team.Red
				end
			elseif tile_team == Team.Other then
				spell_team = Team.Other
			end

			local spell = Spell.new(spell_team)

			-- Use TimeBomb's hit props
			spell:set_hit_props(hit_props)

			spell.on_update_func = function(self)
				self:attack_tile()
				self:delete()
			end

			local explosion = Explosion.new()
			Field.spawn(spell, tile)
			Field.spawn(explosion, tile)
		end

		local function create_explosion_visual_handler()
			-- find tiles using flood fill
			---@type (Tile?)[]
			local pending_visit = { bomb:current_tile() }
			local tile_list = {}
			local visited = {}
			local match_team = bomb:current_tile():team()

			while #pending_visit > 0 do
				local popped = pending_visit[#pending_visit]
				pending_visit[#pending_visit] = nil

				if popped and not visited[popped] and not popped:is_edge() and popped:team() == match_team then
					visited[popped] = true

					-- accept tile
					tile_list[#tile_list + 1] = popped

					-- visit neighbors
					pending_visit[#pending_visit + 1] = popped:get_tile(Direction.Up, 1)
					pending_visit[#pending_visit + 1] = popped:get_tile(Direction.Down, 1)
					pending_visit[#pending_visit + 1] = popped:get_tile(Direction.Left, 1)
					pending_visit[#pending_visit + 1] = popped:get_tile(Direction.Right, 1)
				end
			end

			-- shuffle tiles, aside from the first tile
			for i = 2, #tile_list - 1 do
				local j = math.random(i, #tile_list)
				tile_list[i], tile_list[j] = tile_list[j], tile_list[i]
			end

			local spell = Spell.new()
			local handler = spell:create_component(Lifetime.ActiveBattle)

			local index = 1

			handler.on_update_func = function(self)
				if index > #tile_list then
					self:eject()
					return
				end

				create_explosion_and_visual(tile_list[index])

				index = index + 1
			end
		end

		bomb.on_update_func = function()
			if TurnGauge.frozen() == true then return end

			if countdown:visible() then
				countdown_animator:apply(countdown)
				countdown_animator:update()
			end

			if main_goal == true then
				Resources.play_audio(explosion_audio, AudioBehavior.NoOverlap)

				Field.shake(8, 6)

				countdown:hide()

				create_explosion_visual_handler()
				bomb:erase()
			end
		end

		bomb.on_delete_func = function()
			Field.spawn(Explosion.new(), bomb:current_tile())
			bomb:erase()
		end

		Field.spawn(bomb, spawn_tile)
	end

	return action
end
