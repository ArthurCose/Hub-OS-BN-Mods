nonce = function() end

local DAMAGE = 30
local APPEAR = Resources.load_audio("appear.ogg")
local FWISH = Resources.load_audio("attack.ogg")
local TEXTURE = Resources.load_texture("snake.png")
local SNAKE_FINISHED = true



function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_IDLE")

	action:set_lockout(ActionLockout.new_sequence())
	local anim_ended = false
	action.on_execute_func = function(self, user)
		local step1 = self:create_step()
		local current_x = user:current_tile():x()
		local dir = user:facing()
		local field = user:field()
		local tile_array = {}
		for i = current_x, 6, 1 do
			for j = 0, 6, 1 do
				local tile = field:tile_at(i, j)
				if tile and user:is_team(tile:team()) and not tile:is_edge() and not tile:is_reserved({}) and tile:state() == TileState.Broken then
					table.insert(tile_array, tile)
				end
			end
		end
		local DO_ONCE = false
		step1.on_update_func = function(self)
			if not DO_ONCE then
				DO_ONCE = true
				if #tile_array > 0 then
					for i = 1, #tile_array, 1 do
						Resources.play_audio(APPEAR)
						local snake = spawn_snake(user, props)
						field:spawn(snake, tile_array[i])
					end
				end
			end
			if SNAKE_FINISHED then
				self:complete_step()
			end
		end
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
	SNAKE_FINISHED = false
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Flinch,
			Element.Wood,
			user:context(),
			Drag.None
		)
	)
	local target = user:field():find_nearest_characters(user,
		function(found)
			if not user:is_team(found:team()) and found:health() > 0 then
				return true
			end
		end
	)
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
						SNAKE_FINISHED = true
						self:delete()
					end
					local ref = self
					self:slide(dest, (3), (0),
						function()
							ref.slide_started = true
						end
					)
				end
			else
				cooldown = cooldown - 1
			end
		end
	end

	local anim = spell:animation()
	anim:load("snake.animation")
	anim:set_state("APPEAR")
	spell:animation():on_complete(
		function()
			anim:set_state("ATTACK")
		end
	)

	spell.on_collision_func = function(self, other)
		SNAKE_FINISHED = true
		self:erase()
	end
	spell.can_move_to_func = function(self, other)
		return true
	end
	return spell
end
