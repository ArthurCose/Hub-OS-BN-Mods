local battle_helpers = require("Battle.Helpers")
local bn_assets = require("BattleNetwork.Assets")

local AUDIO_DAMAGE = bn_assets.load_audio("hit_impact.ogg")
local AUDIO_DAMAGE_OBS = bn_assets.load_audio("hit_obstacle.ogg")
local CRACKSHOOT_AUDIO = bn_assets.load_audio("panel_toss2.ogg")
local BLOCKED = bn_assets.load_audio("panel_toss_failed.ogg")

local CRACKSHOOT_TEXTURE = bn_assets.load_texture("spell_panel_shot.png")
local CRACKSHOOT_ANIMPATH = bn_assets.fetch_animation_path("spell_panel_shot.animation")
local DUST_TEXTURE = bn_assets.load_texture("floor_dust.png")
local DUST_ANIMPATH = bn_assets.fetch_animation_path("floor_dust.animation")

local EFFECT_TEXTURE = bn_assets.load_texture("bn6_hit_effects.png")
local EFFECT_ANIMPATH = bn_assets.fetch_animation_path("bn6_hit_effects.animation")

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_SWING")

	local query = function(o)
		return Living.from(o) == nil and not o:hittable()
	end

	local crackshoot_type = "CRACKSHOOT_TYPE_SINGLE"

	for index, value in ipairs(props.tags) do
		print(value)
		if value == "CRACKSHOOT_TYPE_DOUBLE" or value == "CRACKSHOOT_TYPE_TRIPLE" then
			crackshoot_type = value
		end
	end

	action:set_lockout(ActionLockout.new_animation())
	action.on_execute_func = function(self, user)
		local field = user:field()
		local team = user:team()
		local facing = user:facing()
		self:add_anim_action(2, function()
			local hilt = self:create_attachment("HILT")
			local hilt_sprite = hilt:sprite()
			hilt_sprite:set_texture(actor:texture())
			hilt_sprite:set_layer(-2)
			hilt_sprite:use_root_shader(true)

			local hilt_anim = hilt:animation()
			hilt_anim:copy_from(actor:animation())
			hilt_anim:set_state("HAND")
		end)

		self:add_anim_action(3, function()
			local tile1 = user:get_tile(facing, 1)

			create_attack(user, props, team, facing, field, tile1, query)

			if crackshoot_type == "CRACKSHOOT_TYPE_DOUBLE" then
				local tile2 = user:get_tile(facing, 2)

				create_attack(user, props, team, facing, field, tile2, query)
			elseif crackshoot_type == "CRACKSHOOT_TYPE_TRIPLE" then
				local tile2 = tile1:get_tile(Direction.Up, 1)
				local tile3 = tile1:get_tile(Direction.Down, 1)

				create_attack(user, props, team, facing, field, tile2, query)
				create_attack(user, props, team, facing, field, tile3, query)
			end
		end)
	end
	return action
end

function create_attack(user, props, team, facing, field, tile, query)
	local spell = Spell.new(team)

	spell:set_facing(facing)


	if #tile:find_entities(query) > 0 or not tile:is_walkable() then
		Resources.play_audio(BLOCKED)
	else
		spell:set_texture(CRACKSHOOT_TEXTURE)

		local spell_anim = spell:animation()

		local spell_sprite = spell:sprite()

		spell_anim:load(CRACKSHOOT_ANIMPATH)
		spell_anim:set_playback(Playback.Loop)
		spell_sprite:set_offset(0, 12)
		spell_sprite:set_layer(-3)

		if tile:team() == Team.Blue then
			spell_anim:set_state("BLUE_TEAM")
		else
			spell_anim:set_state("RED_TEAM")
		end

		spell_anim:apply(spell_sprite)

		Resources.play_audio(CRACKSHOOT_AUDIO)
	end

	if tile and tile:is_walkable() then
		battle_helpers.create_effect(facing, DUST_TEXTURE, DUST_ANIMPATH, "DEFAULT", 0, 0, -3, field, tile,
			Playback.Once, true, nil)

		if #tile:find_entities(query) > 0 then
			tile:set_state(TileState.Cracked)
		else
			tile:set_state(TileState.Broken)
			spell.slide_started = false
			spell:set_hit_props(
				HitProps.from_card(
					props,
					user:context(),
					Drag.None
				)
			)

			spell.on_update_func = function(self)
				self:current_tile():attack_entities(self)
				if self:offset().y <= 0 then
					if self:is_sliding() == false then
						if self:current_tile():is_edge() and self.slide_started then
							self:delete()
						end

						local dest = self:get_tile(spell:facing(), 1)
						local ref = self
						self:slide(dest, 5, function() ref.slide_started = true end)
					end
				else
					self:set_offset(self:offset().x * 0.5, self:offset().y - 4 * 0.5)
				end
			end
		end

		field:spawn(spell, tile)
	end
	spell.on_collision_func = function(self, other)
		self:delete()
	end
	spell.on_delete_func = function(self)
		self:erase()
	end
	spell.can_move_to_func = function(self, tile)
		return true
	end
	spell.on_attack_func = function(self, ent)
		if facing == Direction.Right then
			battle_helpers.create_effect(facing, EFFECT_TEXTURE, EFFECT_ANIMPATH, "PEASHOT", -20, -15, -999999, field,
				self:current_tile(), Playback.Once, true, nil)
		else
			battle_helpers.create_effect(facing, EFFECT_TEXTURE, EFFECT_ANIMPATH, "PEASHOT", 20, -15, -999999, field,
				self:current_tile(), Playback.Once, true, nil)
		end
		if Character.from(user) ~= nil then
			Resources.play_audio(AUDIO_DAMAGE)
		elseif Obstacle.from(ent) ~= nil then
			Resources.play_audio(AUDIO_DAMAGE_OBS)
		end
	end
	return spell
end
