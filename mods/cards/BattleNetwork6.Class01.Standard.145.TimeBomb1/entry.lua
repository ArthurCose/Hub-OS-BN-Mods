local noop = function() end

local bn_assets = require("BattleNetwork.Assets")

local bomb_texture = bn_assets.load_texture("bn6_timebomb.png")
local bomb_anim_path = bn_assets.fetch_animation_path("bn6_timebomb.animation")

local bomb_timer_audio = bn_assets.load_audio("timebomb1.ogg")
local bomb_ready_audio = bn_assets.load_audio("timebomb2.ogg")
local explosion_audio = bn_assets.load_audio("timebomb3.ogg")

local spawn_audio = bn_assets.load_audio("obstacle_spawn.ogg")

---@param user Entity
---@param tile Tile?
local function is_dest_value(user, tile)
	return tile and
			not tile:is_reserved() and
			tile:is_walkable() and
			tile:team() ~= user:team()
end

---@param user Entity
---@param ranges [number, number, number][]
local function find_dest_in_ranges(user, ranges)
	local player_y = user:current_tile():y()

	for _, range in ipairs(ranges) do
		for x = range[1], range[2], range[3] do
			-- try same row
			local tile = Field.tile_at(x, player_y)

			if is_dest_value(user, tile) then
				return tile
			end

			-- try any
			for y = 0, Field.height() - 1 do
				tile = Field.tile_at(x, y)

				if is_dest_value(user, tile) then
					return tile
				end
			end
		end
	end
end

---@param user Entity
local function find_dest(user)
	local x = user:current_tile():x()
	local x_end = Field.width() - 1

	---@type [number, number, number][]
	local ranges

	if user:facing() == Direction.Right then
		ranges = {
			-- ahead / right
			{ x + 1, x_end, 1 },
			-- same col
			{ x,     x,     1 },
			-- behind / left
			{ 0,     x - 1, 1 }
		}
	else
		ranges = {
			-- ahead / left
			{ x - 1, 0,     -1 },
			-- same col
			{ x,     x,     -1 },
			-- behind / right
			{ x_end, x + 1, -1 },
		}
	end

	return find_dest_in_ranges(user, ranges)
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

		local function create_explosion_and_visual(tile)
			local spell = Spell.new(Team.Other)

			-- Use TimeBomb's hit props
			spell:set_hit_props(hit_props)

			spell.on_update_func = function(self)
				self:attack_tile()
				self:delete()
			end

			local explosion = Explosion.new()
			explosion.on_spawn_func = noop

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
			if countdown:visible() then
				countdown_animator:apply(countdown)
				countdown_animator:update()
			end

			if TurnGauge.frozen() == true then return end

			if main_goal == true then
				Resources.play_audio(explosion_audio, AudioBehavior.NoOverlap)

				Field.shake(8, 6)

				countdown:hide()

				create_explosion_visual_handler()

				bomb:delete()
			end
		end

		bomb.on_delete_func = function()
			bomb:erase()
		end

		Field.spawn(bomb, spawn_tile)
	end

	return action
end
