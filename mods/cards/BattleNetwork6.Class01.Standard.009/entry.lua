local bn_helpers = require("BattleNetwork.Assets")

local BUSTER_TEXTURE = bn_helpers.load_texture("spread_buster.png")
local BUSTER_ANIM_PATH = bn_helpers.fetch_animation_path("spread_buster.animation")
local BURST_TEXTURE = bn_helpers.load_texture("spread_impact.png")
local BURST_ANIM_PATH = bn_helpers.fetch_animation_path("spread_impact.animation")
local AUDIO = bn_helpers.load_audio("spreader.ogg")

local function create_attack(user, props)
	local spell = Spell.new(user:team())
	local direction = user:facing()
	local reverse = user:facing_away()

	spell:set_facing(direction)

	local hit_props = HitProps.from_card(
		props,
		user:context(),
		Drag.None
	)

	spell.on_update_func = function()
		spell:attack_tile()

		if spell:is_moving() then
			return
		end

		local dest = spell:get_tile(direction, 1)

		if dest then
			spell:slide(dest, 2)
		else
			spell:delete()
		end
	end

	spell.on_collision_func = function()
		if spell:deleted() then
			return
		end

		local tile = spell:current_tile()

		local burst_tiles = {
			tile,
			tile:get_tile(Direction.join(direction, Direction.Up), 1),
			tile:get_tile(direction, 1),
			tile:get_tile(Direction.join(direction, Direction.Down), 1),
			tile:get_tile(Direction.Down, 1),
			tile:get_tile(Direction.join(reverse, Direction.Down), 1),
			tile:get_tile(reverse, 1),
			tile:get_tile(Direction.join(reverse, Direction.Up), 1),
			tile:get_tile(Direction.Up, 1),
		}

		for i = 1, #burst_tiles, 1 do
			local spawn_tile = burst_tiles[i]

			if not spawn_tile or spawn_tile:is_edge() then
				goto continue
			end

			local burst = Spell.new(spell:team())
			burst:set_hit_props(hit_props)
			burst:set_texture(BURST_TEXTURE)
			burst:animation():load(BURST_ANIM_PATH)
			burst:animation():set_state("DEFAULT")
			burst:animation():on_complete(function()
				burst:erase()
			end)

			burst:set_elevation(8.0)

			Field.spawn(burst, spawn_tile)

			spawn_tile:attack_entities(burst)

			::continue::
		end

		spell:delete()
	end

	Resources.play_audio(AUDIO)

	return spell
end

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_SHOOT")
	action:override_animation_frames({ { 1, 1 }, { 2, 3 }, { 3, 3 }, { 1, 15 } })

	action:set_lockout(ActionLockout.new_animation())

	action.on_execute_func = function(self, user)
		local buster = self:create_attachment("BUSTER")
		local buster_sprite = buster:sprite()
		buster_sprite:set_texture(BUSTER_TEXTURE)
		buster_sprite:set_layer(-1)
		buster_sprite:use_root_shader()

		local buster_anim = buster:animation()
		buster_anim:load(BUSTER_ANIM_PATH)
		buster_anim:set_state("DEFAULT")

		local tile = user:get_tile(user:facing(), 1)

		if tile then
			local spell = create_attack(user, props)
			Field.spawn(spell, tile)
		end
	end

	return action
end
