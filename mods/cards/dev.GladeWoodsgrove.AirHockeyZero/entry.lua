local TEXTURE = Resources.load_texture("puck.png")
local TEXTURE_ANIM = "puck.animation"
local LAUNCH_AUDIO = Resources.load_audio("pucklaunch.ogg")
local BOUNCE_AUDIO = Resources.load_audio("puckhit.ogg")
local MOB_MOVE_TEXTURE = Resources.load_texture("mob_move.png")
local PARTICLE_TEXTURE = Resources.load_texture("artifact_impact_fx.png")

local frame_data = { { 1, 2 }, { 2, 2 }, { 3, 2 }, { 4, 25 } }
local hand_frame_data = {}

for i = 2, #frame_data do
	local data = frame_data[i]
	hand_frame_data[i - 1] = { data[1] - 1, data[2] }
end

function card_init(user, props)
	local action = Action.new(user, "CHARACTER_SWING")

	action:override_animation_frames(frame_data)
	action:set_lockout(ActionLockout.new_async(32))

	action.on_execute_func = function(self)
		self:add_anim_action(2, function()
			user:set_counterable(true)

			local hilt = self:create_attachment("HILT")

			local hilt_sprite = hilt:sprite()
			hilt_sprite:set_texture(user:texture())
			hilt_sprite:set_layer(-2)
			hilt_sprite:use_root_shader(true)
			hilt_sprite:set_palette(user:palette())

			local hilt_anim = hilt:animation()
			hilt_anim:copy_from(user:animation())
			hilt_anim:set_state("HAND", hand_frame_data)
			hilt_anim:apply(hilt_sprite)
		end)

		self:add_anim_action(3, function()
			local dir = user:facing()
			local tile = user:get_tile(dir, 1)
			if tile then
				local puck = create_puck(user, props)
				user:field():spawn(puck, tile)
			end
		end)

		self:add_anim_action(4, function()
			user:set_counterable(false)
		end)
	end

	action.on_action_end_func = function()
		user:set_counterable(false)
	end

	return action
end

function create_puck(user, props)
	local spell = Spell.new(user:team())
	local tile_count = 11
	local self_team = user:team()
	local direction = Direction.join(user:facing(), Direction.Down)

	local anim = spell:animation()
	anim:load(TEXTURE_ANIM)
	anim:set_state("DEFAULT")
	local sprite = spell:sprite()
	sprite:set_texture(TEXTURE)
	anim:apply(sprite)
	anim:set_playback(Playback.Loop)

	spell:set_tile_highlight(Highlight.Flash)

	spell:set_hit_props(
		HitProps.new(
			props.damage,
			props.hit_flags,
			props.element,
			user:context(),
			Drag.None
		)
	)

	spell.on_update_func = function(self)
		local tile = self:current_tile()
		if not tile then
			self:delete()
			return
		end
		if not tile:is_walkable() then
			self:delete()
			return
		end

		tile:attack_entities(self)

		if tile_count < 1 then
			self:delete()
		end

		if not self:is_sliding() then
			local dest
			local play_bounce
			dest, play_bounce, direction = Bounce(tile, spell, direction, self_team)
			if dest then
				self:slide(dest, 6)
				if play_bounce then
					Resources.play_audio(BOUNCE_AUDIO)
				end
			else
				self:delete()
			end

			tile_count = tile_count - 1
		end
	end

	spell.on_collision_func = function(self, other)
		local fx = Artifact.new()
		fx:set_texture(PARTICLE_TEXTURE)

		local fx_anim = fx:animation()
		fx_anim:load("artifact_impact_fx.animation")
		fx_anim:set_state("BLUE")
		fx_anim:apply(fx:sprite())
		fx_anim:on_complete(function()
			fx:erase()
		end)
		spell:field():spawn(fx, spell:current_tile())
	end

	spell.on_attack_func = function(self, other)
	end

	spell.on_delete_func = function(self)
		if not spell:current_tile():is_edge() then
			--if we're not on an edge tile, which happens mostly at the end of battle for some reason,
			--then spawn a mob move to visually vanish the puck when it deletes.
			--presentation!
			local fx = Artifact.new()

			local fx_anim = fx:animation()
			fx:set_texture(MOB_MOVE_TEXTURE)
			fx_anim:load("mob_move.animation")
			fx_anim:set_state("DEFAULT")
			fx_anim:apply(fx:sprite())
			fx_anim:on_complete(function()
				fx:erase()
			end)
			spell:field():spawn(fx, spell:current_tile():x(), spell:current_tile():y())
		end
		self:erase()
	end

	spell.can_move_to_func = function(tile)
		-- Can't move to tiles that don't exist
		if not tile then return false end

		-- Can't move to unwalkable tiles e.g. broken, missing, and edge tiles.
		if not tile:is_walkable() then return false end
		return true
	end

	Resources.play_audio(LAUNCH_AUDIO)

	return spell
end

function Bounce(tile, spell, direction, self_team)
	local play_bounce = true
	local new_dir = direction
	local tile_team = tile:team() -- this is the team of the tile we're currently on

	-- no entry if the target tile is friendly and we aren't currently on a friendly tile
	local function teamcheck(new_tile)
		local new_tile_team = new_tile:team()
		if (new_tile_team == self_team) and not (new_tile_team == tile_team) then
			return true
		end
		return false
	end

	-- wraps up all the checks into one function and returns true if we can't move to the tile
	local function bad()
		local new_tile = tile:get_tile(new_dir, 1)
		if new_tile and not new_tile:is_walkable() and not new_tile:is_edge() then
			spell:delete()
			return false
		end
		if teamcheck(new_tile) then return true end
		return not spell:can_move_to(new_tile)
	end

	-- check if any tile is accessible, 1) no flip, 2) flip x, 3) flip y, 4) flip x and y
	-- (there's no reason to check x before y, it's arbitrary, but the order matters for the other ones)
	if bad() then
		new_dir = Direction.flip_x(direction)
		if bad() then
			new_dir = Direction.flip_y(direction)
			if bad() then
				new_dir = Direction.reverse(direction)
				if bad() then
					-- by returning false, we nil some expected returns, but it's ok cuz the puck will die immediately
					return false
				end
			end
		end
	else
		play_bounce = false
	end

	direction = new_dir
	local dest = tile:get_tile(direction, 1)
	return dest, play_bounce, direction
end
