local bn_helpers = require("BattleNetwork.Assets")
local battle_helpers = require("Battle.Helpers")

local attachment_animation_path = bn_helpers.fetch_animation_path("cannon_series_bn6.animation")
local explosion_animation_path = bn_helpers.fetch_animation_path("spell_explosion.animation")

local BUSTER_TEXTURE = bn_helpers.load_texture("cannon_series_bn6.png")
local IMPACT_TEXTURE = bn_helpers.load_texture("spell_explosion.png")
-- TODO: Implement proper explosion
local AUDIO = bn_helpers.load_audio("cannon.ogg")

local function explode(spell, target, field, tile)
	if field == nil then field = spell:field() end

	if tile == nil then
		if target ~= nil then tile = target:current_tile() else tile = spell:current_tile() end
	end

	local facing = spell._facing

	local offset_x = math.floor(math.random(-10, 10))
	local offset_y = math.floor(math.random(-10, -25))
	local explosion = battle_helpers.create_effect(facing, IMPACT_TEXTURE, explosion_animation_path, "Default",
		offset_x, offset_y, -3, field, tile, Playback.Once, true, nil)


	-- spawn the explosion
	field:spawn(explosion, tile)
end

local splash_explosion = function(self, other, field)
	local tile = self._tile
	local tile_x = self._tile:x()
	local tile_y = self._tile:y()

	for x = -1, 1, 1 do
		for y = -1, 1, 1 do
			tile = field:tile_at(tile_x + x, tile_y + y)

			if tile and not tile:is_edge() then
				self:attack_tile(tile)

				explode(self, other, field, tile)
			end
		end
	end
end

local function create_attack(user, props, context, facing, is_recipe, field)
	local spell = Spell.new(user:team())

	spell._facing = facing

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
	spell._tile = user:current_tile()

	-- this will be used to teleport 1 frame in.
	spell._first_move = false

	-- the wait is to make the spell count how many frames it waited without moving
	-- the count_to is the amount of frames to wait. NOTE: May need to -1? is 0 > 1 two frames or is it 0 > 1 > 2...?
	spell._wait = 0
	spell._count_to = 2

	-- Spell cycles this every frame.
	spell.on_update_func = function(self)
		-- If the current tile is an edge tile, immediately remove the spell and do nothing else.
		if self._tile:is_edge() then return self:erase() end

		if self._has_collided == true then
			self._wait = self._wait + 1
			if self._wait >= 6 then self:delete() end
			return
		end

		-- Remember your ABCs: Always Be Casting.
		-- Most attacks try to land a hit every frame!
		self._tile:attack_entities(self)

		-- Perform first movement
		if self._first_move == false then
			local dest = self:get_tile(self._facing, 1)
			self:teleport(dest, function()
				spell._tile = dest
				spell._first_move = true
			end)
		else
			-- Begin counting up the wait timer
			self._wait = self._wait + 1

			-- When it hits 2, teleport it.
			if self._wait == 2 then
				-- Obtain a destination tile
				local dest = self:get_tile(self._facing, 1)

				if is_recipe and dest:is_edge() then
					explode(self, nil, field, self._tile)
					splash_explosion(self, nil, field)
					self._count_to = 6
					self._wait = 0
				else
					-- Initiate teleport
					self:teleport(dest, function()
						-- Set current tile property and reset wait timer
						spell._tile = dest
						spell._wait = 0
					end)
				end
			end
		end
	end

	spell._has_collided = false
	-- Upon hitting anything, delete self after exploding
	spell.on_collision_func = function(self, other)
		if not self._has_collided then
			self._count_to = 6
			self._wait = 0

			explode(self, other, nil, nil)
			if is_recipe then splash_explosion(self, other, field) end
			self._has_collided = true
		end
	end

	-- No specialty on actually dealing damage, but left in as reference
	-- "Other" is the entity hit by the attack
	spell.on_attack_func = function(self, other) end

	-- On delete, simply remove the spell.
	-- TODO: Explosion on impact
	spell.on_delete_func = function(self)
		self:erase()
	end

	-- As an invisible projectile no tile blocks its passage
	-- Returning true without checking tiles means the spell can always proceed
	spell.can_move_to_func = function(tile)
		return true
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
		if props.short_name == "Giga Cannon 1" then
			buster_state = "Cannon"
		elseif props.short_name == "Giga Cannon 2" then
			buster_state = "HiCannon"
		elseif props.short_name == "Giga Cannon 3" then
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
		-- obtain field to not call this more than once
		local field = user:field()

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
		if lagging_ghost ~= nil then field:spawn(lagging_ghost, user:current_tile()) end

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
				local cannonshot = create_attack(user, props, context, facing, is_recipe, field)

				-- obtain tile to spawn the attack on and spawn it using the field
				local tile = user:current_tile()
				field:spawn(cannonshot, tile)

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
