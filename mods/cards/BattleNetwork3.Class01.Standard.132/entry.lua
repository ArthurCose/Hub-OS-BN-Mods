local bn_assets = require("BattleNetwork.Assets")
local APPEAR = bn_assets.load_audio("appear.ogg")
local FWISH = bn_assets.load_audio("snake.ogg")
local TEXTURE = bn_assets.load_texture("snake.png")
local ANIM_PATH = bn_assets.fetch_animation_path("snake.animation")

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_IDLE")

	action:set_lockout(ActionLockout.new_async(300))

	local SNAKE_FINISHED = false
	local tile_array = {}

	action.on_execute_func = function(self, user)
		for i = 0, 6, 1 do
			for j = 0, 4, 1 do
				local tile = Field.tile_at(i, j)
				if tile and user:is_team(tile:team()) and not tile:is_edge() and not tile:is_reserved({}) and not tile:is_walkable() then
					table.insert(tile_array, tile)
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
				if i < #tile_array + 1 then
					local snake = spawn_snake(actor, props)
					Field.spawn(snake, tile_array[i])
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

	spell:set_texture(TEXTURE)
	spell:set_facing(user:facing())
	spell:set_offset(0.0 * 0.5, -24.0 * 0.5)

	local direction = user:facing()

	local slide_started = false

	spell:set_hit_props(
		HitProps.from_card(
			props,
			user:context(),
			Drag.None
		)
	)

	local target = Field.find_nearest_characters(user, function(found)
		return not user:is_team(found:team()) and found:hittable()
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

					if self:current_tile():is_edge() and slide_started or self:current_tile() == dest then
						self:delete()
					end

					self:slide(dest, 6, function() slide_started = true end)
				end
			else
				cooldown = cooldown - 1
			end
		end
	end

	local anim = spell:animation()
	anim:load(ANIM_PATH)
	anim:set_state("APPEAR")
	spell:animation():on_complete(function()
		anim:set_state("ATTACK")
	end)

	spell.on_collision_func = function(self, other)
		self:erase()
	end

	return spell
end
