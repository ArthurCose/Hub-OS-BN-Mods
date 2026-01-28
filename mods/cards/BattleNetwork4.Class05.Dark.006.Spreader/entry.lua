local bn_assets = require("BattleNetwork.Assets")

local BUSTER_TEXTURE = bn_assets.load_texture("spread_buster.png")
local BUSTER_ANIM_PATH = bn_assets.fetch_animation_path("spread_buster.animation")
local BURST_TEXTURE = bn_assets.load_texture("spread_impact.png")
local BURST_ANIM_PATH = bn_assets.fetch_animation_path("spread_impact.animation")
local AUDIO = bn_assets.load_audio("spreader.ogg")

local function create_attack(user, props)
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

	spell.on_collision_func = function(self, other)
		if spell:deleted() then
			return
		end

		local tile = spell:current_tile()

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
			local spawn_tile = burst_tiles[i]

			if not spawn_tile or spawn_tile:is_edge() then
				goto continue
			end

			local fx = Artifact.new()
			fx:set_texture(BURST_TEXTURE)
			fx:animation():load(BURST_ANIM_PATH)
			fx:animation():set_state("DARK")
			fx:animation():on_complete(function()
				fx:erase()
			end)

			fx:set_elevation(8.0)

			Field.spawn(fx, spawn_tile)
			spell:attack_tile(spawn_tile)

			::continue::
		end

		spell:delete()
	end

	Resources.play_audio(AUDIO)

	return spell
end

function card_mutate(user, card_index)
	if Player.from(user) == nil then return end
	user:boost_augment("BattleNetwork4.Bugs.PanelBug", 3)
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
		buster_anim:set_state("DARK")

		local tile = user:get_tile(user:facing(), 1)
		if tile then
			local spell = create_attack(user, props)
			Field.spawn(spell, tile)
		end
	end

	return action
end
