local battle_helpers = require("keristero.battle_helpers")

local AUDIO_DAMAGE = Resources.load_audio("hitsound.ogg")
local AUDIO_DAMAGE_OBS = Resources.load_audio("hitsound_obs.ogg")
local CRACKSHOOT_AUDIO_YES = Resources.load_audio("crackshoot_yes.ogg")
local CRACKSHOOT_AUDIO_NO = Resources.load_audio("crackshoot_no.ogg")

local CRACKSHOOT_TEXTURE = Resources.load_texture("spell_panel_shot.png")
local CRACKSHOOT_ANIMPATH = "spell_panel_shot.animation"
local DUST_TEXTURE = Resources.load_texture("dust.png")
local DUST_ANIMPATH = "dust.animation"

local EFFECT_TEXTURE = Resources.load_texture("effect.png")
local EFFECT_ANIMPATH = "effect.animation"

function card_init(actor, props)
	if props.crackshoot_type == nil then
		props.crackshoot_type = 1
	end
	local action = Action.new(actor, "CHARACTER_SWING")
	local dark_query = function(o)
		return Obstacle.from(o) ~= nil and o:health() > 0
	end
	local char_query = function(o)
		return Character.from(o) ~= nil or Player.from(o) ~= nil
	end
	action:set_lockout(ActionLockout.new_animation())
	action.on_execute_func = function(self, user)
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
			if props.crackshoot_type == 1 then
				local tile1 = user:get_tile(facing, 1)
				local check1 = (#tile1:find_entities(char_query) > 0 or #tile1:find_entities(dark_query) > 0 or not tile1:is_walkable())
				if check1 then
					Resources.play_audio(CRACKSHOOT_AUDIO_NO)
				else
					Resources.play_audio(CRACKSHOOT_AUDIO_YES)
				end
				create_attack(user, props, team, facing, tile1, char_query, dark_query)
			elseif props.crackshoot_type == 2 then
				local tile1 = user:get_tile(facing, 1)
				local tile2 = user:get_tile(facing, 2)
				local check1 = (#tile1:find_entities(char_query) > 0 or #tile1:find_entities(dark_query) > 0 or not tile1:is_walkable())
				local check2 = (#tile2:find_entities(char_query) > 0 or #tile2:find_entities(dark_query) > 0 or not tile2:is_walkable())
				if check1 and check2 then
					Resources.play_audio(CRACKSHOOT_AUDIO_NO)
				else
					Resources.play_audio(CRACKSHOOT_AUDIO_YES)
				end
				create_attack(user, props, team, facing, tile1, char_query, dark_query)
				create_attack(user, props, team, facing, tile2, char_query, dark_query)
			elseif props.crackshoot_type == 3 then
				local tile1 = user:get_tile(facing, 1):get_tile(Direction.Up, 1)
				local tile2 = user:get_tile(facing, 1)
				local tile3 = user:get_tile(facing, 1):get_tile(Direction.Down, 1)
				local check1 = (#tile1:find_entities(char_query) > 0 or #tile1:find_entities(dark_query) > 0 or not tile1:is_walkable())
				local check2 = (#tile2:find_entities(char_query) > 0 or #tile2:find_entities(dark_query) > 0 or not tile2:is_walkable())
				local check3 = (#tile3:find_entities(char_query) > 0 or #tile3:find_entities(dark_query) > 0 or not tile3:is_walkable())
				if check1 and check2 and check3 then
					Resources.play_audio(CRACKSHOOT_AUDIO_NO)
				else
					Resources.play_audio(CRACKSHOOT_AUDIO_YES)
				end
				create_attack(user, props, team, facing, tile1, char_query, dark_query)
				create_attack(user, props, team, facing, tile2, char_query, dark_query)
				create_attack(user, props, team, facing, tile3, char_query, dark_query)
			end
		end)
	end
	return action
end

function create_attack(user, props, team, facing, tile, char_query, dark_query)
	local spell = Spell.new(team)
	spell:set_facing(facing)
	if tile then
		if not tile:is_edge() then
			battle_helpers.create_effect(facing, DUST_TEXTURE, DUST_ANIMPATH, "DEFAULT", 0, 0, -3, tile,
				Playback.Once, true, nil)
		end
		if (#tile:find_entities(char_query) > 0 or #tile:find_entities(dark_query) > 0) and tile:is_walkable() then
			tile:set_state(TileState.Cracked)
		elseif (#tile:find_entities(char_query) <= 0 or #tile:find_entities(dark_query) <= 0) and tile:is_walkable() then
			tile:set_state(TileState.Broken)
			spell.slide_started = false
			spell:set_hit_props(
				HitProps.new(
					props.damage,
					props.hit_flags,
					props.element,
					user:context(),
					Drag.None
				)
			)
			local spell_anim_state = "RED_TEAM"
			if tile:team() == Team.Blue then
				spell:animation():set_state("BLUE_TEAM")
			end
			local tile_move_func = function()
				return true
			end
			-- create effect
			spell.spell_anim_effect = battle_helpers.create_effect(facing, CRACKSHOOT_TEXTURE, CRACKSHOOT_ANIMPATH,
				spell_anim_state, 0, 24 * 0.5, -3, tile, Playback.Loop, false, tile_move_func)

			-- let effect move anywhere
			spell.spell_anim_effect.can_move = function() return true end

			spell.on_update_func = function(self)
				self:current_tile():attack_entities(self)
				if self:offset().y <= 0 then
					if self:is_sliding() == false then
						if self:current_tile():is_edge() and self.slide_started then
							self:delete()
						end

						local dest = self:get_tile(spell:facing(), 1)
						local ref = self
						self:slide(dest, (5), (0), function()
							ref.slide_started = true
						end)
					end
				else
					self:set_offset(self:offset().x * 0.5, self:offset().y - 4 * 0.5)
				end
			end
		end

		Field.spawn(spell, tile)
	end
	spell.on_collision_func = function(self, other)
		self.spell_anim_effect:erase()
		self:delete()
	end
	spell.on_attack_func = function(self, ent)
		if facing == Direction.Right then
			battle_helpers.create_effect(facing, EFFECT_TEXTURE, EFFECT_ANIMPATH, "0", -20, -15, -999999, self:current_tile(),
				Playback.Once, true, nil)
		else
			battle_helpers.create_effect(facing, EFFECT_TEXTURE, EFFECT_ANIMPATH, "0", 20, -15, -999999, self:current_tile(),
				Playback.Once, true, nil)
		end
		if Obstacle.from(ent) == nil then
			if Player.from(user) ~= nil then
				Resources.play_audio(AUDIO_DAMAGE)
			end
		else
			Resources.play_audio(AUDIO_DAMAGE_OBS)
		end
	end
	return spell
end
