local bn_assets = require("BattleNetwork.Assets")
local TEXTURE = bn_assets.load_texture("panelgrab.png")
local ANIMATION_PATH = bn_assets.fetch_animation_path("panelgrab.animation")

local START_SFX = bn_assets.load_audio("colorpoint_steal.ogg")
local END_SFX = bn_assets.load_audio("colorpoint_buzz.ogg")

---@param user Entity
function card_init(user, props)
	local action = Action.new(user)
	action:set_lockout(ActionLockout.new_sequence())

	local i = 0
	local step = action:create_step()
	step.on_update_func = function()
		i = i + 1

		if i == 80 then
			step:complete_step()
		end
	end

	local team_to_set = Team.Blue
	if user:team() == Team.Blue then team_to_set = Team.Red end

	local anim_state = "FALL"
	local boost = 10
	if props.short_name == "DblPoint" then
		anim_state = "FALL_ORANGE"
		boost = 20
	end

	local orb_count = 0

	local function create_and_spawn_orb(tile)
		local orb = Artifact.new()
		local orb_sprite = orb:sprite()
		local orb_anim = orb:animation()

		orb_sprite:set_texture(TEXTURE)

		orb_anim:load(ANIMATION_PATH)
		orb_anim:set_state("GRAB")
		orb_anim:on_complete(function()
			tile:set_team(team_to_set, Direction.reverse(tile:facing()))
			orb_anim:set_state(anim_state)
			orb_anim:set_playback(Playback.Loop)
		end)

		orb._wait = 20
		orb._rise = 5
		orb._delete_timer = 6
		orb._target_tile = user:current_tile()
		orb.on_update_func = function(self)
			if self._delete_timer == 0 then
				self:delete()
				return
			end

			if orb_anim:state() == "GRAB" then return end

			if self:current_tile() == self._target_tile then
				self._delete_timer = self._delete_timer - 1
				return
			end

			self._rise = self._rise - 1
			if self._rise > 0 then
				self:set_elevation(self:elevation() + 4)
			end

			orb._wait = orb._wait - 1

			if orb._wait > 0 then
				return
			end

			if self:is_sliding() == true then return end
			self:slide(self._target_tile, 12)
		end

		orb.can_move_to_func = function()
			return true
		end

		orb.on_delete_func = function(self)
			orb_count = orb_count + 1
			Resources.play_audio(END_SFX)
			self:erase()
		end

		Field.spawn(orb, tile)
	end

	action.on_execute_func = function()
		local team = user:team()
		local direction = user:facing()

		local user_tile = user:current_tile()

		local x = user_tile:x()
		local y = user_tile:y()

		local tile_list = Field.find_tiles(function(tile)
			-- Must be same team
			if tile:team() ~= team then return false end

			-- Must be at the edge of our area.
			local check_tile = tile:get_tile(direction, 1)
			if check_tile:team() == team then return false end

			-- If facing left, must be a lesser X value (moving towards left edge of field)
			if direction == Direction.Left and tile:x() > x then return false end

			-- If facing right, must be a greater X value (moving towards right edge of field)
			if direction == Direction.Right and tile:x() < x then return false end

			-- If it's on the same column, we can't use the tile we're on, so exclude that one.
			if x == tile:x() then return tile:y() ~= y end

			-- Can't use broken/permahole panels.
			if not tile:is_walkable() then return false end

			-- We're good to go.
			return true
		end)

		Resources.play_audio(START_SFX)

		for index = 1, #tile_list, 1 do
			create_and_spawn_orb(tile_list[index])
		end
	end

	action.on_action_end_func = function()
		local card = user:field_card(1)
		if card == nil then return end
		if card.can_boost == true then
			card.damage = card.damage + (boost * orb_count)
			card.boosted_damage = card.boosted_damage + (boost * orb_count)
			user:set_field_card(1, card)
		end
	end

	return action
end
