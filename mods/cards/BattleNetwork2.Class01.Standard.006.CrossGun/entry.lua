local bn_assets = require("BattleNetwork.Assets")

local BUSTER_TEXTURE = bn_assets.load_texture("spread_buster.png")
local BUSTER_ANIM_PATH = bn_assets.fetch_animation_path("spread_buster.animation")
local BURST_TEXTURE = bn_assets.load_texture("spread_impact.png")
local BURST_ANIM_PATH = bn_assets.fetch_animation_path("spread_impact.animation")
local AUDIO = bn_assets.load_audio("spreader.ogg")

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_SHOOT")

	action:override_animation_frames(
		{
			{ 1, 1 },
			{ 2, 2 },
			{ 3, 1 },
			{ 4, 16 }
		}
	)

	action:set_lockout(ActionLockout.new_animation())

	local flare_anim = Animation.new(BUSTER_ANIM_PATH)
	local flare;

	action.on_execute_func = function(self, user)
		local buster = self:create_attachment("BUSTER")
		local buster_sprite = buster:sprite()
		buster_sprite:set_texture(user:texture())
		buster_sprite:set_layer(-2)
		buster_sprite:use_root_shader(true)
		buster_sprite:set_palette(user:palette())

		local buster_anim = buster:animation()
		buster_anim:copy_from(user:animation())
		buster_anim:set_state("BUSTER")

		local flare_point = buster_anim:relative_point("endpoint")

		flare = buster_sprite:create_node()

		flare:set_texture(BUSTER_TEXTURE)
		flare:set_offset(flare_point.x, flare_point.y)

		flare_anim:set_state("FLARE")

		self:on_anim_frame(2, function()
			local tile = user:get_tile(user:facing(), 1)
			if tile then
				local cannonshot = create_attack(user, props)
				Field.spawn(cannonshot, tile)
			end
		end)
	end

	action.on_update_func = function()
		if flare == nil then return end
		flare_anim:apply(flare)
		flare_anim:update()
	end
	return action
end

function create_attack(user, props)
	local spell = Spell.new(user:team())
	local direction = user:facing()
	local reverse = user:facing_away()

	spell:set_facing(direction)

	spell:set_hit_props(
		HitProps.from_card(
			props,
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
				tile,
				tile:get_tile(Direction.join(direction, Direction.Up), 1),
				tile:get_tile(Direction.join(direction, Direction.Down), 1),
				tile:get_tile(Direction.join(reverse, Direction.Down), 1),
				tile:get_tile(Direction.join(reverse, Direction.Up), 1)
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
					Field.spawn(fx, spawn_tile)
					if spawn_tile ~= tile then spawn_tile:attack_entities(self) end
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
