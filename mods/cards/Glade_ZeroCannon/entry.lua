local bn_helpers = require("dev.GladeWoodsgrove.BattleNetworkHelpers")

local attachment_animation_path = bn_helpers.fetch_animation_path("cannon_series_bn6.animation")
local explosion_animation_path = bn_helpers.fetch_animation_path("spell_explosion.animation")

local BUSTER_TEXTURE = bn_helpers.load_texture("cannon_series_bn6.png")
local IMPACT_TEXTURE = bn_helpers.load_texture("spell_explosion.png")
-- TODO: Implement proper explosion
local AUDIO = bn_helpers.load_audio("cannon.ogg")

function card_init(actor, props)
	local context = actor:context();

	local action = Action.new(actor, "PLAYER_SHOOTING");

	local action_frame_sequence = {
		{ 1, 4 }, { 2, 3 },
		{ 2, 6 }, { 3, 1 },
		{ 3, 1 }, { 1, 2 },
		{ 1, 2 }, { 1, 2 },
		{ 1, 7 }, { 1, 3 },
		{ 1, 4 },
	};

	action:set_card_properties(props);

	action:override_animation_frames(action_frame_sequence);

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

		self:add_anim_action(2, function()
			-- attack starts, can no longer counter
			user:set_counterable(false)

			-- create cannon arm attachment
			local buster = self:create_attachment("BUSTER")

			-- obtain the sprite so we don't have to call it more than once
			local buster_sprite = buster:sprite()

			-- Set the texture
			buster_sprite:set_texture(BUSTER_TEXTURE, true)
			buster_sprite:set_layer(-1)

			-- Create cannon arm attachment animation
			local buster_anim = buster:animation()
			buster_anim:load(attachment_animation_path)

			-- Decide animation state based on which cannon is being used.
			buster_anim:set_state(props.short_name)
		end)

		self:add_anim_action(5, function()
			-- create the attack itself
			local cannonshot = create_attack(user, props, context, facing, field)

			-- obtain tile to spawn the attack on and spawn it using the field
			local tile = user:current_tile()
			field:spawn(cannonshot, tile)

			-- play a sound to indicate the attack.
			Resources.play_audio(AUDIO)
		end)
	end

	return action;
end

function create_attack(user, props, context, facing, field)
	local spell = Spell.new(user:team())
	spell.facing = facing
	spell:set_facing(facing)
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			props.hit_flags,
			Element.None,
			context,
			Drag.None
		)
	)
	-- store starting tile as the user's own tile
	spell.tile = user:current_tile();

	-- this will be used to teleport 1 frame in.
	spell.first_move = false;

	-- the wait is to make the spell count how many frames it waited without moving
	-- the count_to is the amount of frames to wait. NOTE: May need to -1? is 0 > 1 two frames or is it 0 > 1 > 2...?
	spell.wait = 0;
	spell.count_to = 2;

	-- Spell cycles this every frame.
	spell.on_update_func = function(self)
		-- If the current tile is an edge tile, immediately remove the spell
		if self.tile:is_edge() then
			self:erase()
		end

		-- Remember your ABCs: Always Be Casting.
		-- Most attacks try to land a hit every frame!
		self.tile:attack_entities(self)

		-- Perform first movement
		if self.first_move == false then
			local dest = self:get_tile(self.facing, 1);
			self:teleport(dest, function()
				spell.tile = dest;
				spell.first_move = true;
			end)
		else
			-- Begin counting up the wait timer
			self.wait = self.wait + 1;

			-- When it hits 2, teleport it.
			if self.wait == 2 then
				-- Obtain a destination tile
				local dest = self:get_tile(self.facing, 1);

				-- Initiate teleport
				self:teleport(dest, function()
					-- Set current tile property and reset wait timer
					spell.tile = dest;
					spell.wait = 0;
				end)
			end
		end
	end

	-- Upon hitting anything, delete self
	spell.on_collision_func = function(self, other)
		-- Create an artifact for a visual
		local explosion = Artifact.new();

		-- Set the texture we'll be using
		explosion:set_texture(IMPACT_TEXTURE);

		-- Fetch the animation
		local explosion_animation = explosion:animation();

		-- Load animation resource
		explosion_animation:load(explosion_animation_path);

		-- Set the state so it knows how to animate it
		explosion_animation:set_state("Default");

		-- Tell the explosion to self-delete on animation end
		explosion_animation:on_complete(function()
			explosion:erase()
		end)

		-- give the explosion a bit of an offset
		explosion:set_offset(math.floor(math.random(-10, 10)), math.floor(math.random(-10, -25)));

		-- spawn the explosion
		field:spawn(explosion, spell.tile)

		-- delete the spell
		self:delete()
	end

	-- No specialty on actually dealing damage, but left in as reference
	-- "Other" is the entity hit by the attack
	spell.on_attack_func = function(self, other)
	end

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
