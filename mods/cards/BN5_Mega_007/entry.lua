function card_init(user, props)
	local state = "CHARACTER_IDLE"

	local user_anim = user:animation()

	-- In case an entity without a standard-named state uses it, use the current state of the entity.
	if not user:animation():has_state(state) then state = user:animation():state() end

	-- This chip mod was made with BN4 Mega Man in mind. Be sure to use the proper animation state for him.
	if user_anim:has_state("JUNK_POLTERGEIST") then state = "JUNK_POLTERGEIST" end

	local action = Action.new(user, state)

	local frame_delay = {}

	for i = 1, 10, 1 do
		table.insert(frame_delay, i, { 1, 60 })
	end

	action:override_animation_frames(frame_delay)
	action:set_lockout(ActionLockout.new_animation())

	local obstacle_list;

	local index = 1
	local timer = 0

	action.on_execute_func = function(self, user)
		obstacle_list = Field.find_obstacles(function(obstacle)
			return obstacle:hittable()
		end)
	end

	local function create_elevation_component(entity)
		local component = entity:create_component(Lifetime.Battle)
		component._slide_started = false
		component._shake_wait = 40

		component.on_update_func = function(self)
			if entity:elevation() < entity:height() then
				entity:set_elevation(entity:elevation() + 4)
			else
				while self._shake_wait > 0 do
					self._shake_wait = self._shake_wait - 1
					entity:hit(HitProps.new(0, Hit.None | Hit.Shake, Element.None))
				end


				local list = Field.find_nearest_characters(entity, function(ent)
					if Living.from(ent) == nil then return false end
					if ent:is_team(user:team()) then return false end
					return ent:hittable()
				end)

				if #list < 1 then return entity:delete() end

				local target_tile = list[1]:current_tile()
				local replacement_spell = Spell.new(user:team())
				replacement_spell:set_hit_props(
					HitProps.from_card(
						props,
						user:context(),
						Drag.None
					)
				)

				replacement_spell:set_texture(entity:texture())
				replacement_spell:animation():copy_from(entity:animation())
				replacement_spell:animation():set_state(entity:animation():state())
				replacement_spell:set_facing(entity:facing())
				replacement_spell:set_elevation(entity:elevation())

				replacement_spell._target_tile = target_tile
				replacement_spell._elevation_change = math.min(1, math.ceil(entity:height() / 6))

				replacement_spell.on_spawn_func = function(self)
					entity:erase()
					self:slide(self._target_tile, 6, function()
						self._slide_started = true
					end)
				end

				replacement_spell.on_update_func = function(self)
					if self:is_sliding() == true then
						self:set_elevation(self:elevation() - self._elevation_change)
					elseif self:is_sliding() == false and self._slide_started == true then
						self:attack_tile()
						self:erase()
					end
				end

				Field.spawn(replacement_spell, entity:current_tile())
			end
		end
	end

	local end_wait_delay = 3

	action.on_update_func = function(self)
		timer = timer + 1

		if timer % 20 ~= 0 then return end

		if index > #obstacle_list then
			end_wait_delay = end_wait_delay - 1
			if end_wait_delay <= 0 then self:end_action() end
			return
		end

		local obstacle = table.remove(obstacle_list, index)

		obstacle:cancel_actions()

		create_elevation_component(obstacle)
	end

	return action
end
