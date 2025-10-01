local noop = function() end

local bn_assets = require("BattleNetwork.Assets")

local bomb_texture = bn_assets.load_texture("bn6_timebomb.png")
local bomb_anim_path = bn_assets.fetch_animation_path("bn6_timebomb.animation")

local bomb_timer_audio = bn_assets.load_audio("timebomb1.ogg")
local bomb_ready_audio = bn_assets.load_audio("timebomb2.ogg")
local explosion_audio = bn_assets.load_audio("timebomb3.ogg")

local spawn_audio = bn_assets.load_audio("obstacle_spawn.ogg")

function card_init(user, props)
	local action = Action.new(user)
	local step = action:create_step()

	action:set_lockout(ActionLockout.new_sequence())

	local time = 0
	local spawn_tile;
	local is_preferred = false;

	local spawn_tile_options = Field.find_tiles(function(tile)
		if tile:is_reserved({}) then return false end
		if not tile:is_walkable() then return false end
		if tile:team() == user:team() then return false end

		return true
	end)

	step.on_update_func = function()
		time = time + 1
	end

	action.on_execute_func = function()
		local bomb = Obstacle.new(Team.Other)

		local user_tile = user:current_tile()
		local user_y = user_tile:y()

		local index = 1
		while index < #spawn_tile_options and is_preferred == false do
			spawn_tile = spawn_tile_options[index]

			is_preferred = spawn_tile:y() == user_y

			index = index + 1
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

		bomb._countdown_animator = Animation.new()
		bomb._countdown_animator:load(bomb_anim_path)
		bomb._countdown_animator:set_state("COUNTDOWN")
		bomb._countdown_animator:apply(countdown)

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

		bomb._countdown_animator:on_frame(2, function()
			play_timebomb_sound(false)
		end, true)

		bomb._countdown_animator:on_frame(3, function()
			play_timebomb_sound(false)
		end, true)

		bomb._countdown_animator:on_frame(4, function()
			play_timebomb_sound(true)
		end, true)

		bomb._countdown_animator:on_complete(function()
			main_goal = true
		end)

		local shuffled = {}

		local tile_list = Field.find_tiles(function(t)
			if t:team() == user:team() then return false end
			if t:is_edge() then return false end
			if t == spawn_tile then return false end
			return true
		end)

		for i, v in ipairs(tile_list) do
			local pos = math.random(1, #shuffled + 1)
			table.insert(shuffled, pos, v)
		end

		table.insert(shuffled, 1, spawn_tile)

		bomb.on_spawn_func = function()
			Resources.play_audio(spawn_audio)
		end

		local hit_props = HitProps.from_card(props)

		local function create_explosion_and_visual(tile)
			local spell = Spell.new(user:team())

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
			local handler = user:create_component(Lifetime.ActiveBattle)

			handler._index = 1

			handler.on_update_func = function(self)
				if self._index > #shuffled then
					self:eject()
					return
				end

				create_explosion_and_visual(shuffled[self._index])

				self._index = self._index + 1
			end
		end

		bomb.on_update_func = function()
			if countdown:visible() then
				bomb._countdown_animator:apply(countdown)
				bomb._countdown_animator:update()
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
