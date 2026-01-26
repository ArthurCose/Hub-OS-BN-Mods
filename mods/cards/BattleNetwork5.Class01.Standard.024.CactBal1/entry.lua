local bn_assets = require("BattleNetwork.Assets")


local SHOT_TEXTURE = Resources.load_texture("CactBall.png")
local HIT_EFFECT_TEXTURE = bn_assets.load_texture("bn6_hit_effects.png")
local HIT_EFFECT_ANIM = bn_assets.fetch_animation_path("bn6_hit_effects.animation")

local AUDIO = Resources.load_audio("cactikil_bounce.ogg")

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_SHOOT")

	local start_columns = 0
	local end_columns = Field.width() - 1
	local x_increment = 1

	if (actor:facing() == Direction.Right) then
		start_columns, end_columns = end_columns, start_columns
		x_increment = -x_increment
	end


	local frame_times = { { 1, 26 } }

	action.on_execute_func = function(self, user)
		local buster = self:create_attachment("BUSTER")
		buster:sprite():set_texture(user:texture("battle.png"))
		buster:sprite():set_layer(-1)

		local buster_anim = buster:animation()
		buster_anim:copy_from(user:animation("battle.animation"))
		buster_anim:set_state("BUSTER", frame_times)

		user:set_counterable(false)

		local shot = create_spell(user, props)

		local tile = user:get_tile(user:facing(), 1)

		if tile then
			Field.spawn(shot, tile)
		end
	end

	return action
end

function create_spell(user, props)
	local hits = 8
	local backwards = false
	local first_move = true

	local state = "Cact1"
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_hit_props(
		HitProps.from_card(
			props,
			user:context(),
			Drag.None
		)
	)

	local anim = spell:animation()
	spell:set_texture(SHOT_TEXTURE)
	spell:set_offset(0, -5)
	spell:set_layer(-1)

	local buster_point = user:animation():get_point("BUSTER")
	local origin = user:sprite():origin()

	anim:load("CactBall.animation")


	for _, value in ipairs(props.tags) do
		if value == "Cact1" then
			state = "CACT1"
		elseif value == "Cact2" then
			state = "CACT2"
		elseif value == "Cact3" then
			state = "CACT3"
		end
	end


	anim:set_state(state)
	anim:set_playback(Playback.Loop)

	spell.on_update_func = function(self)
		self:attack_tile()

		if spell:movement_offset().x == 0 and spell:movement_offset().y == 0 then
			Resources.play_audio(AUDIO)
		end

		if backwards then
			local dest = self:get_tile(spell:facing(), -1)

			self:jump(dest, 13, 10)

			backwards = false
			return
		end

		if self:is_moving() then
			return
		end

		local tile = self:current_tile()

		if tile:is_edge() or not tile:is_walkable() then
			self:delete()
		end

		local dest = self:get_tile(spell:facing(), 1)

		if first_move then
			dest = self:get_tile(spell:facing(), 1)
		end

		self:jump(dest, 10, 10)
	end

	spell.on_attack_func = function(self)
		backwards = true
		self:cancel_movement()

		hits = hits - 1
		if hits <= 0 then
			self:delete()
		end
	end

	spell.on_collision_func = function(self, other)
		hits = hits - 1
		local hit_effect = Poof.new()
		local hit_effect_sprite = hit_effect:sprite()
		hit_effect_sprite:set_texture(HIT_EFFECT_TEXTURE)
		local hit_effect_anim = hit_effect:animation()
		hit_effect_anim:load(HIT_EFFECT_ANIM)
		hit_effect_anim:set_state("WOOD")
		hit_effect_anim:on_complete(function()
			hit_effect:delete()
		end)
		Field.spawn(hit_effect, self:current_tile())
	end

	return spell
end
