local bn_assets = require("BattleNetwork.Assets")
local battle_helpers = require("Battle.Helpers")

local attachment_animation_path = bn_assets.fetch_animation_path("cannon_series_bn6.animation")
local explosion_animation_path = bn_assets.fetch_animation_path("spell_explosion.animation")

local BUSTER_TEXTURE = bn_assets.load_texture("cannon_series_bn6.png")
local IMPACT_TEXTURE = bn_assets.load_texture("spell_explosion.png")

local SHOT_TEXTURE = Resources.load_texture("blast.png")
local SHOT_ANIM_PATH = "blast.animation"

-- TODO: Implement proper explosion
local AUDIO = bn_assets.load_audio("cannon.ogg")

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

local function create_attack(user, props)
	local spell = Spell.new(user:team())

	spell:set_facing(user:facing())
	spell:set_texture(SHOT_TEXTURE)

	local anim = spell:animation()
	local buster_point = user:animation():get_point("BUSTER")
	local origin = user:sprite():origin()
	local fire_x = buster_point.x - origin.x --+ (21 - user:current_tile():width())
	local fire_y = buster_point.y - origin.y

	spell:set_offset(fire_x, fire_y)

	anim:load(SHOT_ANIM_PATH)
	anim:set_state("DEFAULT")
	anim:set_playback(Playback.Loop)
	spell:set_hit_props(props)

	-- the wait is to make the spell count how many frames it waited without moving
	-- the count_to is the amount of frames to wait. NOTE: May need to -1? is 0 > 1 two frames or is it 0 > 1 > 2...?
	local wait = 0
	local has_collided = false

	-- Spell cycles this every frame.
	spell.on_update_func = function(self)
		-- If the current tile is an edge tile, immediately remove the spell and do nothing else.
		if spell:current_tile():is_edge() then return self:erase() end

		if has_collided then
			wait = wait + 1
			if wait >= 6 then self:delete() end
			return
		end

		-- Remember your ABCs: Always Be Casting.
		-- Most attacks try to land a hit every frame!
		self:attack_tile()

		-- Obtain a destination tile
		local dest = self:get_tile(self:facing(), 1)

		if not has_collided then
			-- Initiate teleport
			self:slide(dest, 8)
		end
	end

	-- Upon hitting anything, delete self after exploding
	spell.on_collision_func = function(self, other)
		if not has_collided then
			explode(self, other, nil)
			anim:set_state("INVIS")
			has_collided = true
		end
	end

	spell.on_attack_func = function(self, other)
		-- Changes their next attacking chip to Null element.
		local null_prop = AuxProp.new()
			:require_action(ActionType.Card)
			:require_card_damage(Compare.GE, 1)
			:update_context(function(context)
				local card_properties = other:field_card(1)
				if card_properties then
					card_properties.element = Element.None
					card_properties.secondary_element = Element.None
					other:set_field_card(1, card_properties)
				end
				return context
			end)
			:once()
        other:add_aux_prop(null_prop)
	end

	-- return the attack we created for spawning.
	return spell
end

function card_init(user, props)

	-- Decide animation state based on which cannon is being used.
	local buster_state = "Cannon"

	local action = Action.new(user, "CHARACTER_IDLE")
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
		original_offset = user:offset()

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

			user:set_offset(original_offset.x + current_frame[2], original_offset.y)
		end

		user:set_counterable(true)

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
				local hit_props = HitProps.from_card(props, user:context(), Drag.None)
				-- create the attack itself
				local cannonshot = create_attack(user, hit_props)

				-- obtain tile to spawn the attack on and spawn it using the field
				local tile = user:get_tile(user:facing(), 1)
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
			user:set_offset(original_offset.x, original_offset.y)
		end

		user:set_counterable(false)
	end

	return action
end
