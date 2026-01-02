local bn_helpers = require("BattleNetwork.Assets")
local battle_helpers = require("Battle.Helpers")

local attachment_animation_path = bn_helpers.fetch_animation_path("cannon_series_bn6.animation")
local explosion_animation_path = bn_helpers.fetch_animation_path("spell_explosion.animation")

local BUSTER_TEXTURE = bn_helpers.load_texture("cannon_series_bn6.png")
local IMPACT_TEXTURE = bn_helpers.load_texture("spell_explosion.png")
-- TODO: Implement proper explosion
local AUDIO = bn_helpers.load_audio("cannon.ogg")

---@param spell Entity
---@param target Entity?
---@param tile Tile?
local function explode(spell, target, tile)
	if tile == nil then
		if target ~= nil then tile = target:current_tile() else tile = spell:current_tile() end
	end

	local facing = spell:facing()

	local offset_x = math.floor(math.random(-10, 10))
	local offset_y = math.floor(math.random(-10, -25))
	local explosion = battle_helpers.create_effect(facing, IMPACT_TEXTURE, explosion_animation_path, "Default",
		offset_x, offset_y, -3, tile, Playback.Once, true, nil)


	-- spawn the explosion
	Field.spawn(explosion, tile)
end

---@param self Entity
---@param other Entity?
---@param tile Tile
local splash_explosion = function(self, other, tile)
	local tile_x = tile:x()
	local tile_y = tile:y()

	for x = -1, 1, 1 do
		for y = -1, 1, 1 do
			local splash_tile = Field.tile_at(tile_x + x, tile_y + y)

			if splash_tile and not splash_tile:is_edge() then
				self:attack_tile(splash_tile)

				explode(self, other, splash_tile)
			end
		end
	end
end

local function create_attack(user, props, context, facing, is_recipe)
	local spell = Spell.new(user:team())

	spell:set_facing(facing)
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			props.hit_flags,
			props.element,
			props.secondary_element,
			context,
			Drag.None
		)
	)
	-- store starting tile as the user's own tile
	local tile = user:current_tile()

	-- this will be used to teleport 1 frame in.
	local first_move = false

	-- the wait is to make the spell count how many frames it waited without moving
	-- the count_to is the amount of frames to wait. NOTE: May need to -1? is 0 > 1 two frames or is it 0 > 1 > 2...?
	local wait = 0
	local has_collided = false

	-- Spell cycles this every frame.
	spell.on_update_func = function(self)
		-- If the current tile is an edge tile, immediately remove the spell and do nothing else.
		if tile:is_edge() then return self:erase() end

		if has_collided == true then
			wait = wait + 1
			if wait >= 6 then self:delete() end
			return
		end

		-- Remember your ABCs: Always Be Casting.
		-- Most attacks try to land a hit every frame!
		tile:attack_entities(self)

		-- Perform first movement
		if first_move == false then
			local dest = self:get_tile(self:facing(), 1)
			self:teleport(dest, function()
				tile = dest
				first_move = true
			end)
		else
			-- Begin counting up the wait timer
			wait = wait + 1

			-- When it hits 2, teleport it.
			if wait == 2 then
				-- Obtain a destination tile
				local dest = self:get_tile(self:facing(), 1)

				if is_recipe and (not dest or dest:is_edge()) then
					explode(self, nil, tile)
					splash_explosion(self, nil, tile)
					has_collided = true
					wait = 0
				else
					-- Initiate teleport
					self:teleport(dest, function()
						-- Set current tile property and reset wait timer
						tile = dest
						wait = 0
					end)
				end
			end
		end
	end

	has_collided = false
	-- Upon hitting anything, delete self after exploding
	spell.on_collision_func = function(self, other)
		if not has_collided then
			wait = 0

			explode(self, other, nil)
			if is_recipe then splash_explosion(self, other, tile) end
			has_collided = true
		end
	end

	-- return the attack we created for spawning.
	return spell
end

function card_init(actor, props)
	local context = actor:context()

	-- Decide animation state based on which cannon is being used.
	local buster_state = props.short_name

	local lagging_ghost = nil

	local is_recipe = false
	for index, value in ipairs(props.tags) do
		if value == "PROGRAM_ADVANCE" then is_recipe = true end
	end

	-- If it's a Program Advance, set according to the cannons used.
	if is_recipe then
		lagging_ghost = battle_helpers.create_lagging_ghost(actor, Color.new(0, 0, 255, 255))
		if props.short_name == "GigaCan1" then
			buster_state = "Cannon"
		elseif props.short_name == "GigaCan2" then
			buster_state = "HiCannon"
		elseif props.short_name == "GigaCan3" then
			buster_state = "M-Cannon"
		end
	end

	local action = Action.new(actor, "CHARACTER_IDLE")
	action:set_card_properties(props)
	action:set_lockout(ActionLockout.new_sequence())

	-- create a step and drop it to block the action from ending
	-- we'll use action:end_action() to complete the action
	action:create_step()

	local startup_frames = { { 1, 4 } }
	local shoot_frames = { { 1, 3 }, { 1, 6 }, { 2, 2 }, { 3, 13 } }
	local recover_frames = { { 1, 3 } }

	-- startup animation
	action:override_animation_frames(startup_frames)

	local original_offset

	action.on_execute_func = function(self, user)
		-- obtain direction user is facing to not call this more than once
		local facing = user:facing()

		-- handle offset animation
		original_offset = actor:offset()

		local offset_sign = -1
		if facing == Direction.Left then offset_sign = 1 end
		-- [duration, offset_x][]
		local offsets = {
			{ 13, 0 },
			{ 0,  offset_sign * 4 },
			{ 0,  offset_sign * 5 },
			{ 0,  offset_sign * 6 },
			{ 12, offset_sign * 7 },
			{ 99, 0 }
		}

		local offset_elapsed = 0
		local offset_frame = 1

		action.on_update_func = function()
			local current_frame = offsets[offset_frame]

			if offset_elapsed >= current_frame[1] then
				offset_frame = offset_frame + 1
				current_frame = offsets[offset_frame]
				offset_elapsed = 0
			end

			offset_elapsed = offset_elapsed + 1

			actor:set_offset(original_offset.x + current_frame[2], original_offset.y)
		end

		user:set_counterable(true)
		if lagging_ghost ~= nil then Field.spawn(lagging_ghost, user:current_tile()) end

		local animation = user:animation()
		animation:on_complete(function()
			-- attack starts, can no longer counter
			user:set_counterable(false)

			-- switch to the shoot animation
			animation:set_state("CHARACTER_SHOOT", shoot_frames)

			-- create cannon arm attachment
			local buster = self:create_attachment("BUSTER")

			-- obtain the sprite so we don't have to call it more than once
			local buster_sprite = buster:sprite()

			-- Set the texture
			buster_sprite:set_texture(BUSTER_TEXTURE)
			buster_sprite:set_layer(-1)
			buster_sprite:use_root_shader()

			-- Create cannon arm attachment animation
			local buster_anim = buster:animation()
			buster_anim:load(attachment_animation_path)

			buster_anim:set_state(buster_state)

			animation:on_frame(4, function()
				-- create the attack itself
				local cannonshot = create_attack(user, props, context, facing, is_recipe)

				-- obtain tile to spawn the attack on and spawn it using the field
				local tile = user:current_tile()
				Field.spawn(cannonshot, tile)

				-- play a sound to indicate the attack.
				Resources.play_audio(AUDIO)
			end)

			animation:on_complete(function()
				buster_sprite:hide()

				animation:set_state("CHARACTER_IDLE", recover_frames)
				animation:on_complete(function()
					action:end_action()
				end)
			end)
		end)
	end


	action.on_action_end_func = function()
		if original_offset then
			actor:set_offset(original_offset.x, original_offset.y)
		end

		if lagging_ghost then
			lagging_ghost:erase()
		end

		actor:set_counterable(false)
	end

	return action
end
