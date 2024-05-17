local APPEAR = Resources.load_audio("appear.ogg")
local FWISH = Resources.load_audio("attack.ogg")
local TEXTURE = Resources.load_texture("snake.png")

function card_init(actor, props)
	local action = Action.new(actor, "PLAYER_IDLE")

	action:set_lockout(ActionLockout.new_async(300))

	local SNAKE_FINISHED = false

	local field = actor:field()

	action.on_execute_func = function(self, user)
		self.tile_array = {}

		for i = 0, 6, 1 do
			for j = 0, 4, 1 do
				local tile = field:tile_at(i, j)
				if tile and user:is_team(tile:team()) and not tile:is_edge() and not tile:is_reserved({}) and not tile:is_walkable() then
					table.insert(self.tile_array, tile)
				end
			end
		end
	end

	local timer = 50
	local start = 1

	action.on_update_func = function(self)
		if SNAKE_FINISHED and timer <= 0 then
			self:end_action()
		end
		if not SNAKE_FINISHED and timer <= 0 then
			Resources.play_audio(APPEAR, AudioBehavior.NoOverlap)
			print(start)
			for i = start, start + 2, 1 do
				if i < #self.tile_array + 1 then
					local snake = spawn_snake(actor, props)
					field:spawn(snake, self.tile_array[i])
				else
					SNAKE_FINISHED = true
					break;
				end
			end
			start = start + 3
			timer = 50
		end
		timer = timer - 1
	end
	return action
end

function spawn_snake(user, props)
	local spell = Spell.new(user:team())

	spell:set_texture(TEXTURE, true)
	spell:set_facing(user:facing())
	spell:set_offset(0.0 * 0.5, -24.0 * 0.5)

	local direction = user:facing()

	spell.slide_started = false

	spell:set_hit_props(
		HitProps.new(
			props.damage,
			props.hit_flags,
			props.element,
			user:context(),
			Drag.None
		)
	)

	local target = user:field():find_nearest_characters(user, function(found)
		if not user:is_team(found:team()) and found:hittable() then
			return true
		end
	end)
	local cooldown = 8
	local DO_ONCE = false
	spell.on_update_func = function(self)
		self:current_tile():attack_entities(self)
		if spell:animation():state() == "ATTACK" then
			if not DO_ONCE then
				Resources.play_audio(FWISH)
				DO_ONCE = true
			end
			if cooldown <= 0 then
				if self:is_sliding() == false then
					local dest = spell:get_tile(direction, 1)
					if target[1] ~= nil and not target[1]:deleted() then
						dest = target[1]:current_tile()
					end

					if self:current_tile():is_edge() and self.slide_started or self:current_tile() == dest then
						self:delete()
					end

					local ref = self

					self:slide(dest, 6, function() ref.slide_started = true end)
				end
			else
				cooldown = cooldown - 1
			end
		end
	end

	local anim = spell:animation()
	anim:load("snake.animation")
	anim:set_state("APPEAR")
	spell:animation():on_complete(function()
		anim:set_state("ATTACK")
	end)

	spell.on_collision_func = function(self, other)
		self:erase()
	end
	spell.can_move_to_func = function(self, other)
		return true
	end
	return spell
end
