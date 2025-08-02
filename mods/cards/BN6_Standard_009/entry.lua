local bn_helpers = require("BattleNetwork.Assets")

local BUSTER_TEXTURE = bn_helpers.load_texture("spread_buster.png")
local BUSTER_ANIM_PATH = bn_helpers.fetch_animation_path("spread_buster.animation")
local BURST_TEXTURE = bn_helpers.load_texture("spread_impact.png")
local BURST_ANIM_PATH = bn_helpers.fetch_animation_path("spread_impact.animation")
local AUDIO = bn_helpers.load_audio("spreader.ogg")

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
			local cannonshot = create_attack(user, props)
			Field.spawn(cannonshot, tile)
		end
	end
	return action
end

function create_attack(user, props)
	local spell = Spell.new(user:team())
	local direction = user:facing()
	local reverse = user:facing_away()

	spell:set_facing(direction)

	local hit_props = HitProps.from_card(
		props,
		user:context(),
		Drag.None
	)

	spell.slide_started = false

	spell.on_update_func = function(self)
		local tile = spell:current_tile()

		tile:attack_entities(self)

		if self:is_sliding() == false then
			if tile:is_edge() and self.slide_started then
				self:delete()
			end

			local dest = self:get_tile(direction, 1)
			local ref = self
			self:slide(dest, 2, function() ref.slide_started = true end)
		end
	end

	spell.on_collision_func = function()
		if not spell:deleted() then
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
				local burst = Spell.new(spell:team())
				burst:set_hit_props(hit_props)
				burst:set_texture(BURST_TEXTURE)
				burst:animation():load(BURST_ANIM_PATH)
				burst:animation():set_state("DEFAULT")
				burst:animation():on_complete(function()
					burst:erase()
				end)

				burst:set_elevation(8.0)

				local spawn_tile = burst_tiles[i]
				if spawn_tile and not spawn_tile:is_edge() then
					Field.spawn(burst, spawn_tile)
					spawn_tile:attack_entities(burst)
				end
			end

			spell:delete()
		end
	end

	Resources.play_audio(AUDIO)
	return spell
end
