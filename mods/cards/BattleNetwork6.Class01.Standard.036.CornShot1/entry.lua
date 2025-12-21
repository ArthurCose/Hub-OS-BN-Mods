local bn_helpers = require("BattleNetwork.Assets")

local BUSTER_TEXTURE = bn_helpers.load_texture("bn6_cornshot_buster.png")
local BUSTER_ANIM_PATH = bn_helpers.fetch_animation_path("bn6_cornshot_buster.animation")

local EXPLOSION_TEXTURE = bn_helpers.load_texture("explosion_energy_bomb.png")
local EXPLOSION_ANIM_PATH = bn_helpers.fetch_animation_path("explosion_energy_bomb.animation")

local AUDIO = bn_helpers.load_audio("circusman_clap.ogg")

---@type fun(team: Team, facing: Direction, hit_props: HitProps, spawn_tile: Tile?)
local spread_explosion

---@param hit_props HitProps
---@param team Team
---@param facing Direction
---@param spawn_tile Tile?
local function spawn_explosion(team, facing, hit_props, spawn_tile)
	if not spawn_tile then return end

	-- start invisible
	local explosion = Spell.new(team)
	explosion:set_facing(facing)
	explosion:set_hit_props(hit_props)

	-- attack on the first frame
	explosion.on_spawn_func = function()
		explosion:attack_tile()
	end

	local has_collided = false
	local time = 0

	explosion.on_update_func = function(self)
		time = time + 1

		if time == 2 and not has_collided then
			-- delete if we didn't hit anything on the first frame
			explosion:delete()
		elseif time == 13 then
			-- spawn new explosions
			local dir = self:facing()
			local tile_forward = spawn_tile:get_tile(dir, 1)
			local tile_up_forward = spawn_tile:get_tile(Direction.join(dir, Direction.Up), 1)
			local tile_down_forward = spawn_tile:get_tile(Direction.join(dir, Direction.Down), 1)

			spread_explosion(team, facing, hit_props, tile_forward)
			spread_explosion(team, facing, hit_props, tile_up_forward)
			spread_explosion(team, facing, hit_props, tile_down_forward)

			explosion:current_tile():set_state(TileState.Grass)
		elseif time == 15 then
			-- attack again after attempting to spread explosions
			explosion:attack_tile()
		end
	end

	explosion.on_collision_func = function()
		if has_collided then return end
		has_collided = true

		-- display explosion animation
		explosion:set_texture(EXPLOSION_TEXTURE)

		local explosion_anim = explosion:animation()
		explosion_anim:load(EXPLOSION_ANIM_PATH)
		explosion_anim:set_state("CORN")

		explosion_anim:on_complete(function()
			explosion:delete()
		end)
	end

	-- spawn the explosion
	Field.spawn(explosion, spawn_tile)
end

function spread_explosion(team, facing, hit_props, spawn_tile)
	if not spawn_tile then return end

	local has_enemy
	spawn_tile:find_characters(function(c)
		if not has_enemy then
			has_enemy = c:team() ~= team and c:hittable()
		end
		return false
	end)

	if has_enemy then
		spawn_explosion(team, facing, hit_props, spawn_tile)
	end
end

---@param user Entity
---@param props CardProperties
---@param context AttackContext
local function create_projectile(user, props, context)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_hit_props(HitProps.new(0, Hit.Drain, Element.None))

	-- Spell cycles this every frame.
	spell.on_update_func = function()
		-- If the current tile is an edge tile, immediately remove the spell and do nothing else.
		if spell:current_tile():is_edge() then
			spell:delete()
			return
		end

		-- Remember your ABCs: Always Be Casting.
		-- Most attacks try to land a hit every frame!
		spell:attack_tile()

		-- Obtain a destination tile
		local dest = spell:get_tile(spell:facing(), 1)

		-- Move every frame
		spell:teleport(dest)
	end

	-- Upon hitting anything, delete self after exploding
	local collided = false
	spell.on_collision_func = function()
		if collided then
			return
		end

		collided = true

		local hit_props = HitProps.from_card(
			props,
			context,
			Drag.None
		)

		spawn_explosion(spell:team(), spell:facing(), hit_props, spell:current_tile())

		spell:current_tile():set_state(TileState.Grass)
	end

	-- return the attack we created for spawning.
	return spell
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
	local action = Action.new(user, "CHARACTER_SHOOT")
	action:set_lockout(ActionLockout.new_async(24))

	local frame_override_list = {
		{ 1, 10 },
		{ 2, 2 },
		{ 3, 4 },
		{ 4, 18 }
	}

	action:override_animation_frames(frame_override_list)

	action.on_execute_func = function(self, user)
		user:set_counterable(true)

		-- create attachment
		local buster = self:create_attachment("BUSTER")
		local buster_sprite = buster:sprite()

		buster_sprite:set_texture(BUSTER_TEXTURE)
		buster_sprite:set_layer(-1)
		buster_sprite:use_root_shader()

		local buster_anim = buster:animation()
		buster_anim:load(BUSTER_ANIM_PATH)
		buster_anim:set_state("DEFAULT")

		self:on_anim_frame(2, function()
			-- play a sound to indicate the attack.
			Resources.play_audio(AUDIO)

			-- No longer counterable.
			user:set_counterable(false)

			-- create the attack itself
			local spell = create_projectile(user, props, user:context())

			-- obtain tile to spawn the attack on and spawn it using the field
			local tile = user:current_tile()
			Field.spawn(spell, tile)
		end)
	end

	action.on_action_end_func = function()
		user:set_counterable(false)
	end

	return action
end
