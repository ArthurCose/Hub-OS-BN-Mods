local bn_assets = require("BattleNetwork.Assets")

---@type SwordLib
local SwordLib = require("dev.konstinople.library.sword")

local sword = SwordLib.new_sword()
sword:set_frame_data(
	{
		{ 1, 6 }, { 2, 2 }, { 3, 2 }, { 4, 10 }, { 4, 1 }
	}
)
sword:set_default_blade_texture(bn_assets.load_texture("sword_blades.png"))
sword:set_default_blade_animation_path(bn_assets.fetch_animation_path("sword_blades.animation"))

local SLASH_TEXTURE = bn_assets.load_texture("sword_slashes.png")
local SLASH_ANIM_PATH = bn_assets.fetch_animation_path("sword_slashes.animation")
local AUDIO = bn_assets.load_audio("sword.ogg")

---@param user Entity
function card_init(user, props)
	local action = Action.new(user)

	action:set_lockout(ActionLockout.new_sequence()) --Sequence lockout required to use steps & avoid issues with idle
	action.on_execute_func = function()
		local antisword_rule = DefenseRule.new(DefensePriority.Trap, DefenseOrder.CollisionOnly)

		local has_blocked = false

		antisword_rule.defense_func = function(defense, attacker, defender)
			if defense:damage_blocked() then return end

			local hit_props = attacker:copy_hit_props()

			--Simulate cursor removing traps
			if hit_props.element == Element.Cursor or hit_props.secondary_element == Element.Cursor then
				defender:remove_defense_rule(antisword_rule)
				return
			end

			-- Only trigger on Sword hit
			if hit_props.element ~= Element.Sword and hit_props.secondary_element ~= Element.Sword then
				return
			end

			-- Require damage to activate
			if hit_props.damage == 0 then return end

			defense:block_damage()
			if not has_blocked then
				has_blocked = true

				local flags = { Hit.Paralyze, Hit.Freeze } -- Third flag...?

				for i = 1, #flags, 1 do
					user:remove_status(flags[i])
				end

				user:apply_status(Hit.Invincible, 64)

				Player.from(defender):queue_action(poof_user(user, props))

				defender:remove_defense_rule(antisword_rule)
			end
		end

		user:add_defense_rule(antisword_rule)
	end

	return action
end

function poof_user(user, props)
	local action = Action.new(user, "CHARACTER_IDLE")

	action:override_animation_frames({ { 1, 2 } })

	local tile = user:get_tile(user:facing(), 1)

	if tile == nil then return action end
	action:set_lockout(ActionLockout.new_sequence()) --Sequence lockout required to use steps & avoid issues with idle

	sword:create_action_step(action, function()
		spawn_attack(user, props, "SONIC",
			{
				{ x = 0, y = -1 },
				{ x = 0, y = 1 }
			},
			true, false
		)

		Resources.play_audio(AUDIO)
	end)

	sword:create_action_step(action, function()
		spawn_attack(user, props, "SONIC",
			{
				{ x = 0, y = -1 },
				{ x = 0, y = 1 }
			},
			true, false
		)

		Resources.play_audio(AUDIO)
	end)

	sword:create_action_step(action, function()
		spawn_attack(user, props, "SONIC",
			{
				{ x = 0, y = -1 },
				{ x = 0, y = 1 }
			},
			true, false
		)

		Resources.play_audio(AUDIO)
	end)


	return action
end

function spawn_attack(user, props, state, offset_list, is_slide, is_pierce)
	local slash = Spell.new(user:team())
	slash:set_facing(user:facing())

	slash:set_hit_props(
		HitProps.from_card(
			props,
			user:context(),
			Drag.None
		)
	)

	slash:set_texture(SLASH_TEXTURE)

	local anim = slash:animation()

	anim:load(SLASH_ANIM_PATH)
	anim:set_state(state)

	slash._is_slide = is_slide
	slash._is_pierce = is_pierce
	slash._offset_list = offset_list
	slash._has_slid = false

	if is_slide == true then
		anim:set_playback(Playback.Loop)
	else
		anim:on_complete(function()
			slash:delete()
		end)
	end

	slash.can_move_to_func = function(tile)
		if slash._is_pierce == true then return true end
		return slash._is_slide;
	end

	slash.on_update_func = function(self)
		local own_tile = self:current_tile()

		self:attack_tile()

		if #self._offset_list > 1 then
			for index, value in ipairs(self._offset_list) do
				local facing = self:facing()

				if value.x < 0 then facing = self:facing_away() end

				local attack_tile = own_tile:get_tile(facing, math.abs(value.x))

				if attack_tile ~= nil then
					self:attack_tile(attack_tile)
				end

				if value.y < 0 then
					facing = Direction.Up
				else
					facing = Direction.Down
				end
				if attack_tile ~= nil then
					attack_tile = attack_tile:get_tile(facing, math.abs(value.y))
					self:attack_tile(attack_tile)
				end
			end
		end

		if own_tile:is_edge() then return self:delete() end

		if self._is_slide == true and self:is_sliding() == false then
			self:slide(own_tile:get_tile(self:facing(), 1), 4, function()
				self._has_slid = true
			end)
		elseif self._is_slide == false and not self:is_sliding() and self._has_slid == true then
			self:delete()
		end
	end

	slash.on_collision_func = function(self, other)
		if self._is_pierce ~= true then
			self._is_slide = false
		end
		if self._is_slide == true and self._is_pierce == false then self:delete() end
	end

	slash.on_delete_func = function(self)
		self:erase()
	end

	Field.spawn(slash, user:get_tile(user:facing(), 1))
end
