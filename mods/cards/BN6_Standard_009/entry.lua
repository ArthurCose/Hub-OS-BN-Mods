local bn_helpers = require("dev.GladeWoodsgrove.BattleNetworkHelpers")

local BUSTER_TEXTURE = bn_helpers.load_texture("spread_buster.png")
local BUSTER_ANIM_PATH = bn_helpers.fetch_animation_path("spread_buster.animation")
local BURST_TEXTURE = bn_helpers.load_texture("spread_impact.png")
local BURST_ANIM_PATH = bn_helpers.fetch_animation_path("spread_impact.animation")
local AUDIO = bn_helpers.load_audio("spreader.ogg")

function card_init(actor, props)
	local action = Action.new(actor, "PLAYER_SHOOTING")

	action:set_lockout(ActionLockout.new_animation())

	action.on_execute_func = function(self, user)
		local buster = self:create_attachment("BUSTER")
		buster:sprite():set_texture(BUSTER_TEXTURE, true)
		buster:sprite():set_layer(-1)

		local buster_anim = buster:animation()
		buster_anim:load(BUSTER_ANIM_PATH)
		buster_anim:set_state("DEFAULT")

		local cannonshot = create_attack(user, props)
		local tile = user:get_tile(user:facing(), 1)
		actor:field():spawn(cannonshot, tile)
	end
	return action
end

function create_attack(user, props)
	local spell = Spell.new(user:team())
	local direction = user:facing()
	local reverse = user:facing_away()
	local field = user:field()

	spell:set_facing(direction)

	spell:set_hit_props(
		HitProps.new(
			props.damage,
			props.hit_flags,
			props.element,
			user:context(),
			Drag.None
		)
	)

	spell.slide_started = false
	spell.should_erase = false

	spell.on_update_func = function(self)
		local tile = spell:current_tile()
		if self.should_erase == true then
			local burst_tiles = {
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
				local fx = Artifact.new()
				fx:set_texture(BURST_TEXTURE)
				fx:animation():load(BURST_ANIM_PATH)
				fx:animation():set_state("DEFAULT")
				fx:animation():on_complete(function()
					fx:erase()
				end)

				fx:set_elevation(8.0)

				local spawn_tile = burst_tiles[i]
				if spawn_tile and not spawn_tile:is_edge() then
					field:spawn(fx, spawn_tile)
					spawn_tile:attack_entities(self)
				end
			end

			self:delete()

			return
		end

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

	spell.on_collision_func = function(self, other)
		self.should_erase = true;
	end

	spell.on_delete_func = function(self)
		self:erase()
	end

	spell.can_move_to_func = function(tile)
		return true
	end

	Resources.play_audio(AUDIO)
	return spell
end
