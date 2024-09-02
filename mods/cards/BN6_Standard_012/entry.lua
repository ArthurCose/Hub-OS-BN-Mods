local bn_helpers = require("BattleNetwork.Assets")

local TANKCAN_TEXTURE = bn_helpers.load_texture("tank_cannon.png")
local TANKCAN_ANIM = bn_helpers.fetch_animation_path("tank_cannon.animation")
local BLAST_TEXTURE = bn_helpers.load_texture("tank_cannon_hit_effect.png")
local BLAST_ANIM = bn_helpers.fetch_animation_path("tank_cannon_hit_effect.animation")
local BACKROW_BLAST = bn_helpers.load_texture("tank_cannon_blast.png")
local BACKROW_BLAST_ANIM = bn_helpers.fetch_animation_path("tank_cannon_blast.animation")
local AUDIO = bn_helpers.load_audio("tankcannon_main.ogg")
local CANNON = bn_helpers.load_audio("cannon.ogg")

local frame_data = ({ { 1, 37 } })

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_SHOOT")
	local field = actor:field()
	action:override_animation_frames(frame_data)
	action:set_lockout(ActionLockout.new_animation())

	action.on_execute_func = function(self, user)
		local buster = self:create_attachment("BUSTER")
		local buster_sprite = buster:sprite()
		buster_sprite:set_texture(TANKCAN_TEXTURE)
		buster_sprite:set_layer(-1)
		local offset = 0

		local buster_anim = buster:animation()
		buster_anim:load(TANKCAN_ANIM)
		buster_anim:set_state("DEFAULT")

		buster_anim:on_frame(4, function()
			local blast = create_attack(user, props)
			field:spawn(blast, actor:get_tile(actor:facing(), 1))
			field:shake(10, 0.5 * 60)

			Resources.play_audio(CANNON, AudioBehavior.Default)
		end)

		buster_anim:on_frame(5, function()
			offset = -12
			-- if (user:facing() == Direction.Left) then
			-- 	offset = 12
			-- end
			actor:set_offset(offset * 0.5, 0 * 0.5)
		end)

		buster_anim:on_frame(9, function()
			actor:set_offset(0 * 0.5, 0 * 0.5)
		end)
	end

	action.on_action_end_func = function(self)
		actor:set_offset(0 * 0.5, 0 * 0.5)
	end

	return action
end

function create_basic_effect(field, tile, hit_texture, hit_anim_path, hit_anim_state)
	local fx = Artifact.new()
	fx:set_texture(hit_texture)
	local fx_sprite = fx:sprite()
	fx_sprite:set_layer(-3)
	local fx_anim = fx:animation()
	fx_anim:load(hit_anim_path)
	fx_anim:set_state(hit_anim_state)
	fx_anim:apply(fx_sprite)
	fx_anim:on_complete(function()
		fx:erase()
	end)
	field:spawn(fx, tile)
	return fx
end

--filter function to only consider characters or obstacles that are hittable
function filter(ent)
	if ent and not ent:hittable() then return false end
	if Character.from(ent) ~= nil or Obstacle.from(ent) ~= nil then return true end
end

function create_back_attack(user, props)
	local field = user:field()
	local spell = Spell.new(user:team())
	local flags = props.hit_flags & props.hit_flags ~ Hit.Drag
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			flags,
			props.element,
			props.secondary_element,
			user:context(),
			Drag.None
		)
	)

	spell.on_update_func = function(self)
		local tile = self:current_tile()
		local sprite = Artifact.new()
		sprite:set_texture(BLAST_TEXTURE)
		local animation = sprite:animation()
		animation:load(BLAST_ANIM)
		animation:set_state("DEFAULT")
		animation:apply(sprite:sprite())
		animation:on_complete(function()
			sprite:delete()
		end)

		field:spawn(sprite, tile)

		tile:attack_entities(self)

		self:delete()
	end


	return spell
end

function create_attack(user, props)
	local direction = user:facing()
	local away = user:facing_away()
	local field = user:field()
	local spell = Spell.new(user:team())
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Drag | Hit.Flinch | Hit.Flash,
			props.element,
			props.secondary_element,
			user:context(),
			Drag.new(direction, field:width())
		)
	)

	spell.slide_started = false
	spell.do_once = true

	spell.on_update_func = function(self)
		local tile = self:current_tile()
		tile:attack_entities(self)

		if not self:is_sliding() then
			if tile:is_edge() and self.slide_started then
				field:shake(22, 0.5 * 60)
				Resources.play_audio(AUDIO, AudioBehavior.Default)

				local t = self:get_tile(away, 1)
				local blast = create_back_attack(user, props)
				field:spawn(blast, t)
				local tile_up = t:get_tile(Direction.Up, 1)
				local tile_down = t:get_tile(Direction.Down, 1)

				if t:state() == TileState.Cracked then
					t:set_state(TileState.Broken)
				else
					t:set_state(TileState.Cracked)
				end

				if (tile_up ~= nil and not tile_up:is_edge()) then
					create_back_attack(user, props)
					field:spawn(blast, tile_up)
					if tile_up:state() == TileState.Cracked then
						tile_up:set_state(TileState.Broken)
					else
						tile_up:set_state(TileState.Cracked)
					end
				end
				if (tile_down ~= nil and not tile_down:is_edge()) then
					blast = create_back_attack(user, props)
					field:spawn(blast, tile_down)
					if tile_down:state() == TileState.Cracked then
						tile_down:set_state(TileState.Broken)
					else
						tile_down:set_state(TileState.Cracked)
					end
				end

				local effect = create_basic_effect(field, t, BACKROW_BLAST, BACKROW_BLAST_ANIM, "DEFAULT")
				effect:set_facing(direction)

				self:delete()
			end

			local dest = self:get_tile(direction, 1)
			self:slide(dest, 2, function()
				self.slide_started = true
			end)
		end
	end

	spell.on_collision_func = function(self, other)
		local sprite = Artifact.new()
		sprite:set_texture(BLAST_TEXTURE)

		local animation = sprite:animation()
		animation:load(BLAST_ANIM)
		animation:set_state("DEFAULT")
		animation:apply(sprite:sprite())
		animation:on_complete(function()
			sprite:delete()
		end)

		field:spawn(sprite, other:current_tile())

		Resources.play_audio(AUDIO, AudioBehavior.Default)

		self:delete()
	end

	spell.on_delete_func = function(self)
		self:erase()
	end

	spell.can_move_to_func = function(tile)
		return true
	end

	spell.on_attack_func = function() end

	return spell
end
