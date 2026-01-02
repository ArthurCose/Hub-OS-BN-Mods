local bn_assets = require("BattleNetwork.Assets")

local buster_texture = bn_assets.load_texture("bn6_flame_buster.png")
local buster_anim_path = bn_assets.fetch_animation_path("bn6_flame_buster.animation")

local flame_texture = bn_assets.load_texture("bn6_flame_thrower.png")
local flame_animation_path = bn_assets.fetch_animation_path("bn6_flame_thrower.animation")

local hit_texture = bn_assets.load_texture("bn6_hit_effects.png")
local hit_anim_path = bn_assets.fetch_animation_path("bn6_hit_effects.animation")

local AUDIO = bn_assets.load_audio("fireburn.ogg")

local function create_and_spawn_flame_spell(user, props, tile)
	local buster_point = user:animation():get_point("BUSTER")
	local origin = user:sprite():origin()
	local fire_x = buster_point.x - origin.x + 21 - Tile:width()
	local fire_y = buster_point.y - origin.y

	local own_tile;

	local spell = Spell.new(user:team())

	local animation = spell:animation()

	props.package_id = "BattleNetwork6.Class01.Standard.019"

	spell:set_hit_props(
		HitProps.from_card(
			props,
			user:context(),
			Drag.None
		)
	)

	spell:set_texture(flame_texture)

	spell:set_offset(fire_x, fire_y)

	animation:load(flame_animation_path)
	animation:set_state("0")
	animation:set_playback(Playback.Loop)

	spell:set_tile_highlight(Highlight.Solid)

	local sprite = spell:sprite()
	sprite:set_layer(-2)

	animation:apply(sprite)

	spell:set_facing(user:facing())

	spell._has_spawned = false

	spell.on_spawn_func = function(self)
		own_tile = self:current_tile()

		self._has_spawned = true

		if not own_tile:is_walkable() then return end

		if own_tile:state() == TileState.Cracked then
			own_tile:set_state(TileState.Broken)
		else
			own_tile:set_state(TileState.Cracked)
		end
	end

	spell.on_collision_func = function(self, other)
		local fx = Spell.new(self:team())

		fx:set_texture(hit_texture)

		local anim = fx:animation()

		local fx_sprite = fx:sprite()

		anim:load(hit_anim_path)
		anim:set_state("FIRE")

		sprite:set_layer(-3)

		anim:apply(fx_sprite)
		anim:on_complete(function()
			fx:erase()
		end)

		Field.spawn(fx, own_tile)
	end

	spell.on_update_func = function(self)
		self:current_tile():attack_entities(self)
	end

	Field.spawn(spell, tile)

	return spell
end

local function despawn_flame(flame)
	-- Do nothing if it's a nil value
	if not flame then return end

	-- Do nothing if it's already erasing
	if flame:will_erase_eof() then return end

	-- Do nothing if the flame never appeared.
	if flame._has_spawned ~= true then return end

	-- Change the animation and erase on completion.
	local anim = flame:animation()
	anim:set_playback(Playback.Once)
	anim:set_state("1")
	anim:apply(flame:sprite())
	anim:on_complete(function()
		flame:erase()
	end)
end

local function start_despawn(user, flame_list)
	local despawn_component = user:create_component(Lifetime.ActiveBattle)
	despawn_component._index = 1
	despawn_component.on_update_func = function(self)
		if self._index > #flame_list then
			self:eject()
			return
		end

		local fires = flame_list[self._index]
		for _, fire in ipairs(fires) do
			despawn_flame(fire)
		end

		self._index = self._index + 1
	end
end

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_SHOOT")

	local facing;
	local self_tile;

	local frames = { { 1, 35 } }
	action:override_animation_frames(frames)
	action:set_lockout(ActionLockout.new_animation())
	action.on_execute_func = function(self, user)
		self_tile = user:current_tile()
		facing = user:facing()

		local buster = self:create_attachment("BUSTER")
		local buster_sprite = buster:sprite()
		buster_sprite:set_texture(user:texture())
		buster_sprite:set_layer(-2)

		self._flames = {}

		buster_sprite:set_texture(buster_texture)
		buster_sprite:set_layer(-2)

		local buster_anim = buster:animation()
		buster_anim:load(buster_anim_path)
		buster_anim:set_state("0")
		buster_anim:apply(buster_sprite)

		-- spawn first flame
		Resources.play_audio(AUDIO)

		local fire = create_and_spawn_flame_spell(user, props, self_tile:get_tile(facing, 1))

		table.insert(self._flames, { fire })
	end

	local time = 0
	action.on_update_func = function(self)
		time = time + 1

		if time == 5 then
			-- queue spawn frame 5, should appear frame 6
			local tile = self_tile:get_tile(facing, 2)
			local up_tile = tile:get_tile(Direction.Up, 1)
			local down_tile = tile:get_tile(Direction.Down, 1)

			local fire = create_and_spawn_flame_spell(actor, props, tile)
			local fire_up = create_and_spawn_flame_spell(actor, props, up_tile)
			local fire_down = create_and_spawn_flame_spell(actor, props, down_tile)

			table.insert(self._flames, { fire, fire_up, fire_down })
		elseif time == 9 then
			-- queue spawn frame 9, should appear frame 10
			local tile = self_tile:get_tile(facing, 3)
			local up_tile = tile:get_tile(Direction.Up, 1)
			local down_tile = tile:get_tile(Direction.Down, 1)

			local fire = create_and_spawn_flame_spell(actor, props, tile)
			local fire_up = create_and_spawn_flame_spell(actor, props, up_tile)
			local fire_down = create_and_spawn_flame_spell(actor, props, down_tile)

			table.insert(self._flames, { fire, fire_up, fire_down })
		elseif time == 25 then
			start_despawn(actor, self._flames)
		end
	end

	action.on_action_end_func = function(self)
		start_despawn(actor, self._flames)
	end
	return action
end
