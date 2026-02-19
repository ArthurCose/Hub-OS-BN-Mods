---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local flashbomb_hp = 10

---@type BombLib
local BombLib = require("dev.konstinople.library.bomb")

local bomb_texture = bn_assets.load_texture("flashbomb_bn6.png")
local bomb_anim_path = bn_assets.fetch_animation_path("flashbomb_bn6.animation")

local palette_1 = bn_assets.load_texture("palette_flashbomb_1.png")
local palette_2 = bn_assets.load_texture("palette_flashbomb_2.png")
local palette_3 = bn_assets.load_texture("palette_flashbomb_3.png")

local flash_audio = bn_assets.load_audio("flashbomb.ogg")

local explosion_texture = bn_assets.load_texture("flashlight.png")
local explosion_anim_path = bn_assets.fetch_animation_path("flashlight.animation")

local palette;

local bomb = BombLib.new_bomb()
bomb:set_bomb_texture(bomb_texture)
bomb:set_bomb_animation_path(bomb_anim_path)
bomb:set_bomb_shadow(bn_assets.load_texture("bomb_shadow.png"))
bomb:set_execute_sfx(bn_assets.load_audio("lob_bomb.ogg"))
bomb:set_air_duration(50)

bomb:set_bomb_animation_state("FLASH")
bomb:set_bomb_held_animation_state("AIR")

local create_flash_attack = function(user, props)
	if user:deleted() or user:will_erase_eof() then return end

	local spell = Spell.new(user:team())
	spell:set_hit_props(HitProps.from_card(props), user:context())

	spell.on_update_func = function(self)
		self:attack_tile()
		self:erase()
	end

	spell.on_attack_func = function(self, other)
		if other:deleted() or other:will_erase_eof() then return end

		local hit_fx = bn_assets.HitParticle.new("ELEC", math.random(-1, 1), math.random(-0.5, 0.5))

		Field.spawn(hit_fx, other:current_tile())
	end

	return spell
end

local function create_explosion(user, props)
	local team = user:team()
	local explosion = Artifact.new()
	explosion:set_texture(explosion_texture)
	explosion:set_layer(-1)

	local explosion_anim = explosion:animation()
	explosion_anim:load(explosion_anim_path)
	explosion_anim:set_state("DEFAULT")

	explosion_anim:on_complete(function()
		explosion:delete()
	end)

	explosion.on_spawn_func = function()
		Field.find_entities(function(entity)
			if entity:team() == team then
				if team ~= Team.Other then return end
			end

			local attack = create_flash_attack(user, props)

			if attack == nil then return false end

			Field.spawn(attack, entity:current_tile())
		end)
		Resources.play_audio(flash_audio)
	end

	return explosion
end

bomb.swap_bomb_func = function(action)
	local user = action:owner()
	local props = action:copy_card_properties()

	local field_bomb = Obstacle.new(Team.Other)

	field_bomb:set_height(34)

	field_bomb:set_health(flashbomb_hp)

	field_bomb:set_owner(user)

	field_bomb:enable_hitbox(true)

	field_bomb:add_aux_prop(AuxProp.new():declare_immunity(~Hit.None))

	field_bomb:set_texture(bomb_texture)
	field_bomb:set_palette(palette)

	local bomb_anim = field_bomb:animation()
	bomb_anim:load(bomb_anim_path)
	bomb_anim:set_state("IDLE")

	field_bomb:set_facing(user:facing())
	field_bomb:set_shadow(Shadow.Small)

	local timer = 60

	field_bomb.on_update_func = function(self)
		local elevation = field_bomb:elevation()

		if elevation < 16 and elevation > 0 then
			field_bomb:attack_tile()
			field_bomb:enable_hitbox()
		end

		if elevation > 0 then
			return
		end

		if not self:current_tile():is_walkable() then
			self:delete()
			return
		end

		-- Don't count down if already set to erase
		if self:will_erase_eof() then return end

		-- Don't count down during time freeze
		if TurnGauge.frozen() then return end

		if timer == 0 then
			local explosion = create_explosion(user, props)
			explosion:sprite():set_scale(20, 20)
			Field.spawn(explosion, Field.tile_at(0, 0))
			self:delete()
			return
		end

		timer = timer - 1
	end

	field_bomb.on_collision_func = function()
		field_bomb:delete()
	end

	field_bomb.on_delete_func = function()
		field_bomb:erase()
	end

	field_bomb:enable_hitbox(false)

	return field_bomb
end

---@param user Entity
function card_init(user, props)
	if props.short_name == "FlshBom2" then
		bomb:set_bomb_palette(palette_2)
		palette = palette_2
		flashbomb_hp = 15
	elseif props.short_name == "FlshBom3" then
		bomb:set_bomb_palette(palette_3)
		palette = palette_3
		flashbomb_hp = 20
	else
		bomb:set_bomb_palette(palette_1)
		palette = palette_1
	end


	return bomb:create_action(user, function(main_tile, field_bomb)
		if not main_tile or not main_tile:is_walkable() then return end

		field_bomb:enable_hitbox()
	end)
end
