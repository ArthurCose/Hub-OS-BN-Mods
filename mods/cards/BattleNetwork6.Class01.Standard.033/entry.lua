local bn_assets = require("BattleNetwork.Assets")

local buster_texture = bn_assets.load_texture("buster_satellite.png")
local buster_anim_path = bn_assets.fetch_animation_path("buster_satellite.animation")

local spell_texture = bn_assets.load_texture("bn6_elec_pulse.png")
local spell_anim_path = bn_assets.fetch_animation_path("bn6_elec_pulse.animation")

local audio = bn_assets.load_audio("elecpulse.ogg")

function card_init(actor, props)
	local FRAMES = { { 1, 2 }, { 1, 1 }, { 1, 59 } }

	local action = Action.new(actor, "CHARACTER_SHOOT")

	local start_cancel_timer = false;
	local can_use_use = false;

	action:override_animation_frames(FRAMES)

	action:set_lockout(ActionLockout.new_animation())

	action.on_execute_func = function(self, user)
		local buster = self:create_attachment("BUSTER")
		local buster_sprite = buster:sprite()
		buster_sprite:set_texture(buster_texture)
		buster_sprite:set_layer(-1)
		local buster_anim = buster:animation()

		buster_anim:load(buster_anim_path)
		buster_anim:set_state("WAIT")
		buster_anim:apply(buster_sprite)
		buster_anim:on_complete(function()
			buster_anim:set_state("LOOP")
			buster_anim:set_playback(Playback.Loop)
		end)

		self:add_anim_action(2, function()
			start_cancel_timer = true

			local pulse = create_pulse(actor, props)

			local tile = user:get_tile(user:facing(), 1)

			user:field():spawn(pulse, tile)
		end)
	end

	local function check_input()
		if Player.from(actor) == nil then return false end

		local result = false

		if actor:input_has(Input.Pressed.Use) or actor:input_has(Input.Held.Use) and can_use_use == true then
			result = true
			local card = actor:field_card(1)
			if card ~= nil then
				actor:queue_action(Action.from_card(actor, card))
				actor:remove_field_card(1)
			end
		elseif actor:input_has(Input.Pressed.Shoot) or actor:input_has(Input.Held.Shoot) then
			result = true
		elseif actor:input_has(Input.Pressed.Left) or actor:input_has(Input.Held.Left) then
			if actor:can_move_to(actor:get_tile(Direction.Left, 1)) then
				result = true
			end
		elseif actor:input_has(Input.Pressed.Right) or actor:input_has(Input.Held.Right) then
			if actor:can_move_to(actor:get_tile(Direction.Right, 1)) then
				result = true
			end
		elseif actor:input_has(Input.Pressed.Up) or actor:input_has(Input.Held.Up) then
			if actor:can_move_to(actor:get_tile(Direction.Up, 1)) then
				result = true
			end
		elseif actor:input_has(Input.Pressed.Down) or actor:input_has(Input.Held.Down) then
			if actor:can_move_to(actor:get_tile(Direction.Down, 1)) then
				result = true
			end
		end

		return result
	end

	local cancel_timer = 0
	action.on_update_func = function()
		if can_use_use == false then
			if not actor:input_has(Input.Held.Use) and not actor:input_has(Input.Pressed.Use) then can_use_use = true end
		end

		if start_cancel_timer == false then return end

		cancel_timer = cancel_timer + 1

		if cancel_timer < 15 then return end

		if check_input() then action:end_action() end
	end

	return action
end

function create_pulse(user, props)
	local spell = Spell.new(user:team())

	spell:set_facing(user:facing())

	local direction = user:facing()

	local drag = Drag.None

	if props.hit_flags & Hit.Drag == Hit.Drag then
		drag = Drag.new(Direction.reverse(direction), 1)
	end

	spell:set_hit_props(
		HitProps.from_card(
			props,
			user:context(),
			drag
		)
	)

	local spell_sprite = spell:sprite()

	spell_sprite:set_layer(-2)

	spell_sprite:set_texture(spell_texture)

	local buster_point = user:animation():get_point("BUSTER")
	local origin = user:sprite():origin()
	local offset = buster_point.y - origin.y + 10

	spell:set_offset(spell_sprite:offset().x, offset)

	local spell_anim = spell:animation()
	spell_anim:load(spell_anim_path)

	spell_anim:set_state(props.short_name)
	spell_anim:set_playback(Playback.Loop)

	local tiles = {
		user:get_tile(direction, 1),
		user:get_tile(direction, 2),
		user:get_tile(direction, 2):get_tile(Direction.Up, 1),
		user:get_tile(direction, 2):get_tile(Direction.Down, 1)
	}

	local spell_time = 60 -- Lifetime of the hitboxes in frames
	local attacked = false

	spell.on_update_func = function(self)
		if spell_time <= 0 then
			self:delete()
			return
		end

		spell_time = spell_time - 1

		for index, tile in ipairs(tiles) do
			tile:set_highlight(Highlight.Solid)
		end

		if attacked == true then return end

		self:attack_tiles(tiles)
	end

	spell.on_collision_func = function()
		attacked = true
	end

	spell.on_attack_func = function(self, entity)
		if Player.from(entity) == nil then return end

		if props.short_name == "ElcPuls3" then
			entity:boost_augment("BattleNetwork6.Bugs.BattleHPBug", 1)
		elseif props.short_name == "DestPuls" then
			local blind_aux = AuxProp.new()
					:immediate()
					:apply_status(Hit.Blind, 1200)

			local paralyze_aux = AuxProp.new()
					:immediate()
					:apply_status(Hit.Paralyze, 150)

			entity:boost_augment("BattleNetwork6.Bugs.DamageHPBug", 2)
			entity:boost_augment("BattleNetwork6.Bugs.CustomBug", 2)

			entity:add_aux_prop(blind_aux)
			entity:add_aux_prop(paralyze_aux)
		end
	end

	spell.on_delete_func = function(self)
		self:erase()
	end

	spell.can_move_to_func = function(tile)
		return true
	end

	Resources.play_audio(audio)

	return spell
end
