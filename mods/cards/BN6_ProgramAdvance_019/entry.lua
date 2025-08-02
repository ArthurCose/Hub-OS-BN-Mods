local bn_helpers = require("BattleNetwork.Assets")

local BUSTER_TEXTURE = bn_helpers.load_texture("spread_buster.png")
local BUSTER_ANIM_PATH = bn_helpers.fetch_animation_path("spread_buster.animation")
local BURST_TEXTURE = bn_helpers.load_texture("spread_impact.png")
local BURST_ANIM_PATH = bn_helpers.fetch_animation_path("spread_impact.animation")
local AUDIO = bn_helpers.load_audio("spreader.ogg")
local HIT_AUDIO = bn_helpers.load_audio("hit_impact.ogg")

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_SHOOT")

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
	local team = user:team()
	local spell = Spell.new(team)
	local direction = user:facing()

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

	spell.hit_tiles = {}
	spell.hit_tiles_index = 1
	spell.hits_tracked = 0
	spell.hit_timer = nil
	spell.has_collided = false;

	spell.on_update_func = function(self)
		local tile = spell:current_tile()
		tile:attack_entities(self)
		-- Check and update frames to accurately strike.
		if self.hit_timer ~= nil then self.hit_timer = self.hit_timer + 1 end
		-- Delete has priority.
		if self.should_erase == true then
			self:delete()
		elseif self.has_collided == true and self.hit_timer % 10 == 0 then -- Strike every ten frames.
			-- Play sounds
			Resources.play_audio(HIT_AUDIO, AudioBehavior.NoOverlap)

			-- Strike tiles
			for i = 1, #self.hit_tiles[self.hit_tiles_index], 1 do
				local spawn_tile = self.hit_tiles[self.hit_tiles_index][i]
				spawn_spread_burst(spawn_tile, user, props)
			end

			-- Update tracking of hits to delete accurately
			self.hits_tracked = self.hits_tracked + 1

			self.hit_tiles_index = self.hit_tiles_index + 1
			if self.hit_tiles_index > 2 then self.hit_tiles_index = 1 end

			-- If we reach or exceed five attacks, delete.
			-- Since the center tile is struck each rotation, 5 attacks will hit the center 10 times.
			if self.hits_tracked >= 10 then
				self.should_erase = true
				self.has_collided = false
				self.hit_timer = nil
			end
		elseif self:is_sliding() == false and self.has_collided ~= true then
			if tile:is_edge() and self.slide_started then
				self:delete()
			end

			local dest = self:get_tile(direction, 1)
			local ref = self
			self:slide(dest, 2, function() ref.slide_started = true end)
		end
	end

	spell.on_collision_func = function(self, other)
		if self.has_collided == false then
			self.hits_tracked = self.hits_tracked + 1

			local tile = self:current_tile()
			table.insert(self.hit_tiles, {
				tile,
				tile:get_tile(Direction.UpLeft, 1),
				tile:get_tile(Direction.UpRight, 1),
				tile:get_tile(Direction.DownLeft, 1),
				tile:get_tile(Direction.DownRight, 1)
			})
			table.insert(self.hit_tiles, {
				tile,
				tile:get_tile(Direction.Left, 1),
				tile:get_tile(Direction.Right, 1),
				tile:get_tile(Direction.Up, 1),
				tile:get_tile(Direction.Down, 1)
			})

			-- Inform spell of its own collision
			self.has_collided = true;
			-- Start counting frames for hits in the update loop
			self.hit_timer = 0
		end
	end

	spell.on_delete_func = function(self)
		self:erase()
	end

	spell.can_move_to_func = function(tile)
		return true
	end

	Resources.play_audio(AUDIO);

	return spell
end

function spawn_spread_burst(tile, user, props)
	local team = user:team()
	local fx = Artifact.new()
	fx:set_texture(BURST_TEXTURE)
	fx:animation():load(BURST_ANIM_PATH)
	fx:animation():set_state("DEFAULT")
	fx:animation():on_complete(function()
		fx:erase()
	end)

	fx:set_elevation(8.0)

	local burst_spell = Spell.new(team)

	burst_spell:set_hit_props(
		HitProps.from_card(
			props,
			user:context(),
			Drag.None
		)
	)

	burst_spell.on_collision_func = function(self)
		self:erase()
	end

	if tile and not tile:is_edge() then
		Field.spawn(fx, tile)
		tile:attack_entities(burst_spell)
	end
end
