local DAMAGE = 70

local VOICE_FLASHLIGHT_1 = Resources.load_audio("furasshuraito1.ogg")
local VOICE_FLASHLIGHT_2 = Resources.load_audio("furasshuraito2.ogg")

local TEXTURE_FLASHMAN = Resources.load_texture("flashman.png")
local ANIMPATH_FLASHMAN = "flashman.animation"
local AUDIO_SPAWN = Resources.load_audio("spawn.ogg")

local TEXTURE_FLASHLIGHT = Resources.load_texture("flashlight.png")
local ANIMPATH_FLASHLIGHT = "flashlight.animation"
local AUDIO_FLASHLIGHT = Resources.load_audio("flashlight.ogg")

local TEXTURE_EFFECT = Resources.load_texture("effect.png")
local ANIMPATH_EFFECT = "effect.animation"
local AUDIO_DAMAGE = Resources.load_audio("hitsound.ogg")



function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_IDLE")
	action:set_lockout(ActionLockout.new_sequence())
	action.on_execute_func = function(self, user)
		local actor = self:owner()
		actor:hide()

		local NOT_HOLE = nil

		local VOICEACTING = false
		local input_time = 50
		local voiceline_number = 0

		local team = user:team()
		local direction = user:facing()
		local self_tile = user:current_tile()

		local friendly_query = function(ent)
			if user:is_team(ent:team()) then
				return true
			end
		end
		local dark_query = function(o)
			return Obstacle.from(o) ~= nil and o:health() > 0
		end

		local step1 = self:create_step()

		self.flashman = nil

		local ref = self

		local do_once = true
		local do_once_part_two = true
		step1.on_update_func = function(self)
			if input_time > 0 then
				input_time = input_time - 1
				if user:input_has(Input.Held.Use) then
					VOICEACTING = true
				end
			end
			if not not user:current_tile():is_walkable() then
				NOT_HOLE = true
			else
				NOT_HOLE = false
			end
			if do_once then
				do_once = false
				ref.flashman = Artifact.new()
				ref.flashman:set_facing(direction)
				local boss_sprite = ref.flashman:sprite()
				boss_sprite:set_layer(-5)
				boss_sprite:set_texture(TEXTURE_FLASHMAN, true)
				local boss_anim = ref.flashman:animation()
				boss_anim:load(ANIMPATH_FLASHMAN)
				if NOT_HOLE then
					boss_anim:set_state("SPAWN")
					boss_anim:apply(boss_sprite)
				else
					boss_anim:set_state("HOLE")
					boss_anim:apply(boss_sprite)
				end
				boss_anim:on_frame(2, function()
					voiceline_number = math.random(1, 2)
					Resources.play_audio(AUDIO_SPAWN)
				end)
				boss_anim:on_frame(13, function()
					if VOICEACTING then
						if voiceline_number == 1 then
							print("FlashMan: FlashLight!")
							Resources.play_audio(VOICE_FLASHLIGHT_1)
						end
					end
				end)
				boss_anim:on_complete(function()
					if NOT_HOLE then
						boss_anim:set_state("ATTACK")
						boss_anim:apply(boss_sprite)
					else
						ref.flashman:erase()
						step1:complete_step()
					end
				end)
				Field.spawn(ref.flashman, self_tile)
			end
			local anim = ref.flashman:animation()
			if anim:state() == "ATTACK" then
				if do_once_part_two then
					do_once_part_two = false
					anim:on_frame(3, function()
						if VOICEACTING then
							if voiceline_number == 2 then
								print("FlashMan: FlashLight!")
								Resources.play_audio(VOICE_FLASHLIGHT_2)
							end
						end
					end)
					anim:on_frame(7, function()
						if not VOICEACTING then
							print("FlashMan: FlashLight!")
						end
						Resources.play_audio(AUDIO_FLASHLIGHT)
						for i = 1, 6, 1 do
							for j = 1, 3, 1 do
								local tile = Field.tile_at(i, j)
								if tile == self_tile then
									print("user tile found, skipping")
								elseif #tile:find_characters(friendly_query) > 0 or #tile:find_entities(dark_query) > 0 then
									print("friendly/obstacle tile found, skipping")
								else
									create_attack(user, props, team, direction, tile)
								end
							end
						end
						local flashlight = Artifact.new()
						flashlight:set_facing(Direction.Right)
						local flashlight_sprite = flashlight:sprite()
						local flashlight_anim = flashlight:animation()
						flashlight_sprite:set_layer(1)
						flashlight_sprite:set_texture(TEXTURE_FLASHLIGHT, true)
						flashlight_anim:load(ANIMPATH_FLASHLIGHT)
						flashlight_anim:set_state("DEFAULT")
						flashlight_anim:apply(flashlight_sprite)
						flashlight_anim:on_complete(function()
							flashlight:erase()
						end)
						Field.spawn(flashlight, 1, 1)
					end)
					anim:on_complete(function()
						anim:set_state("END")
						anim:apply(ref.flashman:sprite())
						anim:on_complete(function()
							ref.flashman:erase()
							step1:complete_step()
						end)
					end)
				end
			end
		end
	end
	action.on_action_end_func = function(self)
		actor:reveal()
	end
	return action
end

function create_attack(user, props, team, direction, tile)
	local spell = Spell.new(team)
	spell:set_facing(direction)
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Flinch | Hit.Paralyze | Hit.PierceInvis,
			props.element,
			user:context(),
			Drag.None
		)
	)

	local animation = spell:animation()
	animation:load("attack.animation")
	animation:set_state("1")
	animation:on_complete(function()
		spell:erase()
	end)

	spell.on_update_func = function(self)
		self:current_tile():attack_entities(self)
	end

	spell.can_move_to_func = function(self, other)
		return true
	end

	spell.on_battle_end_func = function(self)
		spell:erase()
	end

	spell.on_attack_func = function(self)
		Resources.play_audio(AUDIO_DAMAGE)
		create_effect(TEXTURE_EFFECT, ANIMPATH_EFFECT, "ELEC", math.random(-5, 5), math.random(-5, 5),
			self:current_tile())
	end

	Field.spawn(spell, tile)

	return spell
end

function create_effect(effect_texture, effect_animpath, effect_state, offset_x, offset_y, tile)
	local hitfx = Artifact.new()
	hitfx:set_facing(Direction.Right)
	hitfx:set_texture(effect_texture)
	hitfx:set_offset(offset_x * 0.5, offset_y * 0.5)
	local hitfx_sprite = hitfx:sprite()
	hitfx_sprite:set_layer(-99999)
	local hitfx_anim = hitfx:animation()
	hitfx_anim:load(effect_animpath)
	hitfx_anim:set_state(effect_state)
	hitfx_anim:apply(hitfx_sprite)
	hitfx_anim:on_complete(function()
		hitfx:erase()
	end)
	Field.spawn(hitfx, tile)

	return hitfx
end
