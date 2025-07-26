local bn_helpers = require("BattleNetwork.Assets")

local attachment_animation_path = bn_helpers.fetch_animation_path("bn6_cornshot_buster.animation")
local explosion_animation_path = bn_helpers.fetch_animation_path("explosion_energy_bomb.animation")

local BUSTER_TEXTURE = bn_helpers.load_texture("bn6_cornshot_buster.png")
local IMPACT_TEXTURE = bn_helpers.load_texture("explosion_energy_bomb.png")

local HIT_OBSTACLE = bn_helpers.load_audio("hit_obstacle.ogg")
local HIT_ENEMY = bn_helpers.load_audio("hit_impact.ogg")

local AUDIO = bn_helpers.load_audio("circusman_clap.ogg")

local function play_explosion_audio(other)
	if Obstacle.from(other) ~= nil then
		Resources.play_audio(HIT_OBSTACLE)
	else
		Resources.play_audio(HIT_ENEMY)
	end
end

local function create_and_spawn_explosion(spell, spawn_tile)
	if spawn_tile == nil or spawn_tile:is_edge() then return end
	if #spawn_tile:find_entities(function(ent)
				if Character.from(ent) == nil then return false end
				if not ent:hittable() then return false end
				if ent:team() == spell:team() then return false end
				return true
			end) == 0 then
		return
	end

	local field = spell:field()

	local explosion = Spell.new(spell:team())

	explosion:set_facing(spell:facing())

	explosion:sprite():set_texture(IMPACT_TEXTURE)

	explosion:set_hit_props(spell:copy_hit_props())

	local explosion_anim = explosion:animation()
	explosion_anim:load(explosion_animation_path)
	explosion_anim:set_state("CORN")

	explosion_anim:on_frame(6, function()
		explosion._can_attack = true
	end)

	explosion._has_collided = false

	explosion_anim:on_complete(function()
		explosion:hide()
	end)

	explosion._timer = 12

	explosion.on_update_func = function(self)
		if self._has_collided == true then
			self._timer = self._timer - 1
			if self._timer == 0 then
				self:delete()
			end
			return
		end

		if self._can_attack == true then self:attack_tile() end
	end

	explosion.on_attack_func = function(self, other)
		play_explosion_audio(other)
	end

	explosion.on_collision_func = function(self, other)
		self._has_collided = true

		local dir = self:facing()
		local tile_forward = spawn_tile:get_tile(dir, 1)
		local tile_up_forward = spawn_tile:get_tile(Direction.join(dir, Direction.Up), 1)
		local tile_down_forward = spawn_tile:get_tile(Direction.join(dir, Direction.Down), 1)

		create_and_spawn_explosion(self, tile_forward)
		create_and_spawn_explosion(self, tile_up_forward)
		create_and_spawn_explosion(self, tile_down_forward)

		play_explosion_audio(other)

		other:current_tile():set_state(TileState.Grass)
	end

	-- spawn the explosion
	field:spawn(explosion, spawn_tile)
end

local function create_attack(user, props, context, facing, is_recipe, field)
	local spell = Spell.new(user:team())

	spell._facing = facing

	spell:set_facing(facing)
	spell:set_hit_props(
		HitProps.from_card(
			props,
			context,
			Drag.None
		)
	)
	-- store starting tile as the user's own tile
	spell._tile = user:current_tile();
	spell._has_collided = false
	spell._timer = 13
	spell._collision_tile = nil

	-- Spell cycles this every frame.
	spell.on_update_func = function(self)
		-- If the current tile is an edge tile, immediately remove the spell and do nothing else.
		if self._tile:is_edge() then
			self:erase()
			return
		end

		if self._has_collided == true then
			self._timer = self._timer - 1

			if self._timer == 0 then
				self:delete()
			end

			return
		end

		-- Remember your ABCs: Always Be Casting.
		-- Most attacks try to land a hit every frame!
		self._tile:attack_entities(self)

		-- Obtain a destination tile
		local dest = self:get_tile(self._facing, 1);

		-- Move every frame
		self:teleport(dest, function()
			spell._tile = dest;
		end)
	end

	-- Upon hitting anything, delete self after exploding
	spell.on_collision_func = function(self, other)
		self._has_collided = true

		play_explosion_audio(other)

		create_and_spawn_explosion(self, other:current_tile())

		other:current_tile():set_state(TileState.Grass)
	end

	-- No specialty on actually dealing damage, but left in as reference
	-- "Other" is the entity hit by the attack
	spell.on_attack_func = function(self, other)
		play_explosion_audio(other)
	end

	-- On delete, simply remove the spell.
	spell.on_delete_func = function(self)
		self:erase()
	end

	-- As an invisible projectile no tile blocks its passage
	-- Returning true without checking tiles means the spell can always proceed
	spell.can_move_to_func = function(tile)
		return not spell._has_collided
	end

	-- return the attack we created for spawning.
	return spell
end

function card_init(actor, props)
	local context = actor:context();

	-- Decide animation state based on which cannon is being used.
	local action = Action.new(actor, "CHARACTER_SHOOT");
	action:set_lockout(ActionLockout.new_async(24))

	local frame_override_list = {
		{ 1, 10 },
		{ 2, 2 },
		{ 3, 4 },
		{ 4, 18 }
	}

	action:override_animation_frames(
		frame_override_list
	)

	action.on_execute_func = function(self, user)
		-- obtain field to not call this more than once
		local field = user:field();

		-- obtain direction user is facing to not call this more than once
		local facing = user:facing();

		-- add action on animation index 1
		self:add_anim_action(1, function()
			-- action starts, enable countering
			user:set_counterable(true);
		end)

		self:add_anim_action(1, function()
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

			buster_anim:set_state("DEFAULT")
		end)

		self:add_anim_action(2, function()
			-- play a sound to indicate the attack.
			Resources.play_audio(AUDIO)

			-- No longer counterable.
			user:set_counterable(false)

			-- create the attack itself
			local cannonshot = create_attack(user, props, context, facing, props.short_name == "CornFst", field)

			-- obtain tile to spawn the attack on and spawn it using the field
			local tile = user:current_tile()
			field:spawn(cannonshot, tile)
		end)
	end

	return action;
end
