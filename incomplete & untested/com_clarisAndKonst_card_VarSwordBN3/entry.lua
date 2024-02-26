nonce = function() end

local SLASH_TEXTURE = Resources.load_texture("spell_sword_slashes.png")
local BLADE_TEXTURE = Resources.load_texture("spell_sword_blades.png")
local DREAM_TEXTURE = Resources.load_texture("spell_dreamsword.png")
local AUDIO = Resources.load_audio("sfx.ogg")
local SUCCESS_AUDIO = Resources.load_audio("input.ogg", true)





local recipes = {
	{
		name = "long",
		pattern = {
			{ "down" },
			{ "down", "right" },
			{ "right" }
		}
	},
	{
		name = "wide",
		pattern = {
			{ "up" },
			{ "right" },
			{ "down" }
		}
	},
	{
		name = "fighter",
		pattern = {
			{ "left" },
			{ "down" },
			{ "right" },
			{ "up" },
			{ "left" }
		}
	},
	{
		name = "sonic",
		pattern = {
			{ "left" },
			{ "b" },
			{ "right" },
			{ "b" }
		}
	},
	{
		name = "dream",
		pattern = {
			{ "down" },
			{ "left" },
			{ "up" },
			{ "right" },
			{ "down" }
		}
	},
	{
		name = "elemental",
		pattern = {
			{ "b" },
			{ "b" },
			{ "left" },
			{ "down" },
			{ "up" }
		}
	}
}

local function deep_clone(t)
	if type(t) ~= "table" then
		return t
	end

	local o = {}
	for k, v in pairs(t) do
		o[k] = deep_clone(v)
	end
	return o
end

local function contains(t, value)
	for k, v in ipairs(t) do
		if v == value then
			return true
		end
	end
	return false
end

local function get_first_completed_recipe(matching)
	for _, recipe in ipairs(matching) do
		if recipe.current_step > #recipe.pattern then
			Resources.play_audio(SUCCESS_AUDIO)
			return recipe.name
		end
	end

	return nil
end

function card_init(actor, props)
	local matching = deep_clone(recipes)

	for _, recipe in ipairs(matching) do
		recipe.current_step = 1
	end

	local action = Action.new(actor, "IDLE")
	action:set_lockout(ActionLockout.new_sequence())

	local remaining_time = 50 -- 50 frame timer

	local step1 = self:create_step()
	step1.on_update_func = function()
		remaining_time = remaining_time - 1

		if remaining_time < 0 or not actor:input_has(Input.Pressed.Use) and not actor:input_has(Input.Held.Use) or get_first_completed_recipe(matching) ~= nil then
			step1:complete_step()
			return
		end

		local drop_list = {}
		local inputs = {
			up = actor:input_has(Input.Pressed.Up),
			down = actor:input_has(Input.Pressed.Down),
			left = actor:input_has(Input.Pressed.Left),
			right = actor:input_has(Input.Pressed.Right),
			b = actor:input_has(Input.Pressed.Shoot)
		}

		local function inputs_fail(required_inputs)
			-- has an input that should not be held
			for name, held in pairs(inputs) do
				if held and not contains(required_inputs, name) then
					return true
				end
			end
			return false
		end

		local function inputs_match(required_inputs)
			for _, name in ipairs(required_inputs) do
				if not inputs[name] then
					return false
				end
			end

			return true
		end

		for i, recipe in ipairs(matching) do
			local last_required_inputs = recipe.pattern[recipe.current_step - 1]
			local required_inputs = recipe.pattern[math.min(recipe.current_step, #recipe.pattern)]
			local fails_current_requirements = inputs_fail(required_inputs)

			if fails_current_requirements and (not last_required_inputs or inputs_fail(last_required_inputs)) then
				-- has an input that failed to match the current + previous requirements
				drop_list[#drop_list + 1] = i
			elseif not fails_current_requirements and recipe.current_step <= #recipe.pattern and inputs_match(required_inputs) then
				-- has all of the required inputs to continue
				recipe.current_step = recipe.current_step + 1
			end
		end

		for i, v in ipairs(drop_list) do
			table.remove(matching, v - i + 1)
		end
	end



	local step2 = self:create_step()
	step2.on_update_func = function()
		local attack_name = get_first_completed_recipe(matching)



		if attack_name == "elemental" then
			take_elemental_action(actor, props)
		elseif attack_name == "wide" then
			take_wide_action(actor, props)
		elseif attack_name == "sonic" then
			take_sonic_action(actor, props)
		elseif attack_name == "long" then
			take_long_action(actor, props)
		elseif attack_name == "dream" then
			take_dream_action(actor, props)
		elseif attack_name == "fighter" then
			take_fighter_action(actor, props)
		else
			take_default_action(actor, props)
		end
		step2:complete_step()
	end


	return action
end

-- actual attacks
function take_default_action(actor, props)
	local action = Action.new(actor, "PLAYER_SWORD")
	action:set_lockout(ActionLockout.new_animation())
	action:add_anim_action(2, function()
		local hilt = action:create_attachment("HILT")
		local hilt_sprite = hilt:sprite()
		hilt_sprite:set_texture(actor:texture())
		hilt_sprite:set_layer(-2)
		hilt_sprite:use_root_shader(true)

		local hilt_anim = hilt:animation()
		hilt_anim:copy_from(actor:animation())
		hilt_anim:set_state("HILT")

		local blade = hilt:create_attachment("ENDPOINT")
		local blade_sprite = blade:sprite()
		blade_sprite:set_texture(BLADE_TEXTURE)
		blade_sprite:set_layer(-1)

		local blade_anim = blade:animation()
		blade_anim:load("spell_sword_blades.animation")
		blade_anim:set_state("DEFAULT")
	end)
	action:add_anim_action(3, function()
		local sword = create_normal_slash(actor, props)
		local tile = actor:get_tile(actor:facing(), 1)
		local fx = Artifact.new()
		fx:set_facing(sword:facing())
		local anim = fx:animation()
		fx:set_texture(SLASH_TEXTURE, true)
		anim:load("spell_sword_slashes.animation")
		anim:set_state("DEFAULT")
		anim:on_complete(function()
			fx:erase()
			sword:erase()
		end)
		local field = actor:field()
		field:spawn(fx, tile)
		field:spawn(sword, tile)
	end)
	actor:queue_action(action)
end

function take_wide_action(actor, props)
	local action = Action.new(actor, "PLAYER_SWORD")
	action:set_lockout(ActionLockout.new_animation())
	action:add_anim_action(2, function()
		local hilt = action:create_attachment("HILT")
		local hilt_sprite = hilt:sprite()
		hilt_sprite:set_texture(actor:texture())
		hilt_sprite:set_layer(-2)
		hilt_sprite:use_root_shader(true)

		local hilt_anim = hilt:animation()
		hilt_anim:copy_from(actor:animation())
		hilt_anim:set_state("HILT")

		local blade = hilt:create_attachment("ENDPOINT")
		local blade_sprite = blade:sprite()
		blade_sprite:set_texture(BLADE_TEXTURE)
		blade_sprite:set_layer(-1)

		local blade_anim = blade:animation()
		blade_anim:load("spell_sword_blades.animation")
		blade_anim:set_state("DEFAULT")
	end)
	action:add_anim_action(3, function()
		local sword = create_wide_slash(actor, props)
		local tile = actor:get_tile(actor:facing(), 1)
		local fx = Artifact.new()
		fx:set_facing(sword:facing())
		local anim = fx:animation()
		fx:set_texture(SLASH_TEXTURE, true)
		anim:load("spell_sword_slashes.animation")
		anim:set_state("WIDE")
		anim:on_complete(function()
			fx:erase()
			sword:erase()
		end)
		local field = actor:field()
		field:spawn(fx, tile)
		field:spawn(sword, tile)
	end)
	actor:queue_action(action)
end

function take_sonic_action(actor, props)
	local action = Action.new(actor, "PLAYER_SWORD")
	action:set_lockout(ActionLockout.new_animation())
	action:add_anim_action(2, function()
		local hilt = action:create_attachment("HILT")
		local hilt_sprite = hilt:sprite()
		hilt_sprite:set_texture(actor:texture())
		hilt_sprite:set_layer(-2)
		hilt_sprite:use_root_shader(true)

		local hilt_anim = hilt:animation()
		hilt_anim:copy_from(actor:animation())
		hilt_anim:set_state("HILT")

		local blade = hilt:create_attachment("ENDPOINT")
		local blade_sprite = blade:sprite()
		blade_sprite:set_texture(BLADE_TEXTURE)
		blade_sprite:set_layer(-1)

		local blade_anim = blade:animation()
		blade_anim:load("spell_sword_blades.animation")
		blade_anim:set_state("DEFAULT")
	end)
	action:add_anim_action(3, function()
		local sword = create_sonic_slash(actor, props)
		local tile = actor:get_tile(actor:facing(), 1)
		local fx = Artifact.new()
		fx:set_facing(sword:facing())
		local field = actor:field()
		field:spawn(sword, tile)
	end)
	actor:queue_action(action)
	action.on_action_end_func = function(self)
		local action2 = Action.new(actor, "PLAYER_SWORD")
		action2:set_lockout(ActionLockout.new_animation())
		action2:add_anim_action(3, function()
			local hilt = action2:create_attachment("HILT")
			local hilt_sprite = hilt:sprite()
			hilt_sprite:set_texture(actor:texture())
			hilt_sprite:set_layer(-2)
			hilt_sprite:use_root_shader(true)

			local hilt_anim = hilt:animation()
			hilt_anim:copy_from(actor:animation())
			hilt_anim:set_state("HILT")

			local blade = hilt:create_attachment("ENDPOINT")
			local blade_sprite = blade:sprite()
			blade_sprite:set_texture(BLADE_TEXTURE)
			blade_sprite:set_layer(-1)

			local blade_anim = blade:animation()
			blade_anim:load("spell_sword_blades.animation")
			blade_anim:set_state("DEFAULT")
		end)
		action2:add_anim_action(3, function()
			local sword = create_sonic_slash(actor, props)
			local tile = actor:get_tile(actor:facing(), 1)
			local fx = Artifact.new()
			fx:set_facing(sword:facing())
			local field = actor:field()
			field:spawn(sword, tile)
		end)
		actor:queue_action(action2)
		action2.on_action_end_func = function(self)
			local action3 = Action.new(actor, "PLAYER_SWORD")
			action3:set_lockout(ActionLockout.new_animation())
			action3:add_anim_action(3, function()
				local hilt = action3:create_attachment("HILT")
				local hilt_sprite = hilt:sprite()
				hilt_sprite:set_texture(actor:texture())
				hilt_sprite:set_layer(-2)
				hilt_sprite:use_root_shader(true)

				local hilt_anim = hilt:animation()
				hilt_anim:copy_from(actor:animation())
				hilt_anim:set_state("HILT")

				local blade = hilt:create_attachment("ENDPOINT")
				local blade_sprite = blade:sprite()
				blade_sprite:set_texture(BLADE_TEXTURE)
				blade_sprite:set_layer(-1)

				local blade_anim = blade:animation()
				blade_anim:load("spell_sword_blades.animation")
				blade_anim:set_state("DEFAULT")
			end)
			action3:add_anim_action(3, function()
				local sword = create_sonic_slash(actor, props)
				local tile = actor:get_tile(actor:facing(), 1)
				local fx = Artifact.new()
				fx:set_facing(sword:facing())
				local field = actor:field()
				field:spawn(sword, tile)
			end)
			actor:queue_action(action3)
		end
	end
end

function take_long_action(actor, props)
	local action = Action.new(actor, "PLAYER_SWORD")
	action:set_lockout(ActionLockout.new_animation())
	action:add_anim_action(2, function()
		local hilt = action:create_attachment("HILT")
		local hilt_sprite = hilt:sprite()
		hilt_sprite:set_texture(actor:texture())
		hilt_sprite:set_layer(-2)
		hilt_sprite:use_root_shader(true)

		local hilt_anim = hilt:animation()
		hilt_anim:copy_from(actor:animation())
		hilt_anim:set_state("HILT")

		local blade = hilt:create_attachment("ENDPOINT")
		local blade_sprite = blade:sprite()
		blade_sprite:set_texture(BLADE_TEXTURE)
		blade_sprite:set_layer(-1)

		local blade_anim = blade:animation()
		blade_anim:load("spell_sword_blades.animation")
		blade_anim:set_state("DEFAULT")
	end)
	action:add_anim_action(3, function()
		local sword = create_long_slash(actor, props)
		local tile = actor:get_tile(actor:facing(), 1)
		local fx = Artifact.new()
		fx:set_facing(sword:facing())
		local anim = fx:animation()
		fx:set_texture(SLASH_TEXTURE, true)
		anim:load("spell_sword_slashes.animation")
		anim:set_state("LONG")
		anim:on_complete(function()
			fx:erase()
			sword:erase()
		end)
		local field = actor:field()
		field:spawn(fx, tile)
		field:spawn(sword, tile)
	end)
	actor:queue_action(action)
end

function take_fighter_action(actor, props)
	local action = Action.new(actor, "PLAYER_SWORD")
	action:set_lockout(ActionLockout.new_animation())
	action:add_anim_action(2, function()
		local hilt = action:create_attachment("HILT")
		local hilt_sprite = hilt:sprite()
		hilt_sprite:set_texture(actor:texture())
		hilt_sprite:set_layer(-2)
		hilt_sprite:use_root_shader(true)

		local hilt_anim = hilt:animation()
		hilt_anim:copy_from(actor:animation())
		hilt_anim:set_state("HILT")

		local blade = hilt:create_attachment("ENDPOINT")
		local blade_sprite = blade:sprite()
		blade_sprite:set_texture(BLADE_TEXTURE)
		blade_sprite:set_layer(-1)

		local blade_anim = blade:animation()
		blade_anim:load("spell_sword_blades.animation")
		blade_anim:set_state("DEFAULT")
	end)
	action:add_anim_action(3, function()
		local sword = create_fighter_slash(actor, props)
		local tile = actor:get_tile(actor:facing(), 1)
		local fx = Artifact.new()
		fx:set_facing(sword:facing())
		local anim = fx:animation()
		fx:set_texture(SLASH_TEXTURE, true)
		anim:load("spell_sword_slashes.animation")
		anim:set_state("BIG")
		anim:on_complete(function()
			fx:erase()
			sword:erase()
		end)
		local field = actor:field()
		field:spawn(fx, tile)
		field:spawn(sword, tile)
	end)
	actor:queue_action(action)
end

function take_dream_action(actor, props)
	local action = Action.new(actor, "PLAYER_SWORD")
	action:set_lockout(ActionLockout.new_animation())
	action:add_anim_action(2, function()
		local hilt = action:create_attachment("HILT")
		local hilt_sprite = hilt:sprite()
		hilt_sprite:set_texture(actor:texture())
		hilt_sprite:set_layer(-2)
		hilt_sprite:use_root_shader(true)

		local hilt_anim = hilt:animation()
		hilt_anim:copy_from(actor:animation())
		hilt_anim:set_state("HILT")

		local blade = hilt:create_attachment("ENDPOINT")
		local blade_sprite = blade:sprite()
		blade_sprite:set_texture(BLADE_TEXTURE)
		blade_sprite:set_layer(-1)

		local blade_anim = blade:animation()
		blade_anim:load("spell_sword_blades.animation")
		blade_anim:set_state("DEFAULT")
	end)
	action:add_anim_action(3, function()
		local sword = create_dream_slash(actor, props)
		local tile = actor:get_tile(actor:facing(), 1)
		local fx = Artifact.new()
		fx:set_facing(sword:facing())
		local anim = fx:animation()
		fx:set_texture(DREAM_TEXTURE, true)
		anim:load("spell_dreamsword.animation")
		anim:set_state("DEFAULT")
		anim:on_complete(function()
			fx:erase()
			sword:erase()
		end)
		local field = actor:field()
		field:spawn(fx, tile)
		field:spawn(sword, tile)
	end)
	actor:queue_action(action)
end

function take_elemental_action(actor, props)
	local action = Action.new(actor, "PLAYER_SWORD")
	action:set_lockout(ActionLockout.new_animation())
	action:add_anim_action(2, function()
		local hilt = action:create_attachment("HILT")
		local hilt_sprite = hilt:sprite()
		hilt_sprite:set_texture(actor:texture())
		hilt_sprite:set_layer(-2)
		hilt_sprite:use_root_shader(true)

		local hilt_anim = hilt:animation()
		hilt_anim:copy_from(actor:animation())
		hilt_anim:set_state("HILT")

		local blade = hilt:create_attachment("ENDPOINT")
		local blade_sprite = blade:sprite()
		blade_sprite:set_texture(BLADE_TEXTURE)
		blade_sprite:set_layer(-1)

		local blade_anim = blade:animation()
		blade_anim:load("spell_sword_blades.animation")
		blade_anim:set_state("DEFAULT")
	end)
	action:add_anim_action(3, function()
		local sword = create_fire_slash(actor, props)
		local tile = actor:get_tile(actor:facing(), 1)
		local field = actor:field()
		field:spawn(sword, tile)
	end)
	actor:queue_action(action)
	action.on_action_end_func = function(self)
		local action2 = Action.new(actor, "PLAYER_SWORD")
		action2:set_lockout(ActionLockout.new_animation())
		action2:add_anim_action(3, function()
			local hilt = action2:create_attachment("HILT")
			local hilt_sprite = hilt:sprite()
			hilt_sprite:set_texture(actor:texture())
			hilt_sprite:set_layer(-2)
			hilt_sprite:use_root_shader(true)

			local hilt_anim = hilt:animation()
			hilt_anim:copy_from(actor:animation())
			hilt_anim:set_state("HILT")

			local blade = hilt:create_attachment("ENDPOINT")
			local blade_sprite = blade:sprite()
			blade_sprite:set_texture(BLADE_TEXTURE)
			blade_sprite:set_layer(-1)

			local blade_anim = blade:animation()
			blade_anim:load("spell_sword_blades.animation")
			blade_anim:set_state("DEFAULT")
		end)
		action2:add_anim_action(3, function()
			local sword = create_aqua_slash(actor, props)
			local tile = actor:get_tile(actor:facing(), 1)
			local field = actor:field()
			field:spawn(sword, tile)
		end)
		actor:queue_action(action2)
		action2.on_action_end_func = function(self)
			local action3 = Action.new(actor, "PLAYER_SWORD")
			action3:set_lockout(ActionLockout.new_animation())
			action3:add_anim_action(3, function()
				local hilt = action3:create_attachment("HILT")
				local hilt_sprite = hilt:sprite()
				hilt_sprite:set_texture(actor:texture())
				hilt_sprite:set_layer(-2)
				hilt_sprite:use_root_shader(true)

				local hilt_anim = hilt:animation()
				hilt_anim:copy_from(actor:animation())
				hilt_anim:set_state("HILT")

				local blade = hilt:create_attachment("ENDPOINT")
				local blade_sprite = blade:sprite()
				blade_sprite:set_texture(BLADE_TEXTURE)
				blade_sprite:set_layer(-1)

				local blade_anim = blade:animation()
				blade_anim:load("spell_sword_blades.animation")
				blade_anim:set_state("DEFAULT")
			end)
			action3:add_anim_action(3, function()
				local sword = create_elec_slash(actor, props)
				local tile = actor:get_tile(actor:facing(), 1)
				local field = actor:field()
				field:spawn(sword, tile)
			end)
			actor:queue_action(action3)
			action3.on_action_end_func = function(self)
				local action4 = Action.new(actor, "PLAYER_SWORD")
				action4:set_lockout(ActionLockout.new_animation())
				action4:add_anim_action(3, function()
					local hilt = action4:create_attachment("HILT")
					local hilt_sprite = hilt:sprite()
					hilt_sprite:set_texture(actor:texture())
					hilt_sprite:set_layer(-2)
					hilt_sprite:use_root_shader(true)

					local hilt_anim = hilt:animation()
					hilt_anim:copy_from(actor:animation())
					hilt_anim:set_state("HILT")

					local blade = hilt:create_attachment("ENDPOINT")
					local blade_sprite = blade:sprite()
					blade_sprite:set_texture(BLADE_TEXTURE)
					blade_sprite:set_layer(-1)

					local blade_anim = blade:animation()
					blade_anim:load("spell_sword_blades.animation")
					blade_anim:set_state("DEFAULT")
				end)
				action4:add_anim_action(3, function()
					local sword = create_wood_slash(actor, props)
					local tile = actor:get_tile(actor:facing(), 1)
					local field = actor:field()
					field:spawn(sword, tile)
				end)
				actor:queue_action(action4)
			end
		end
	end
end

-- slashes
function create_normal_slash(user, props)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_tile_highlight(Highlight.Flash)
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Flinch | Hit.Flash,
			props.element,
			user:context(),
			Drag.None
		)
	)

	spell.on_update_func = function(self)
		self:current_tile():attack_entities(self)
	end

	spell.can_move_to_func = function(tile)
		return true
	end

	Resources.play_audio(AUDIO)

	return spell
end

function create_wide_slash(user, props)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_tile_highlight(Highlight.Flash)
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Flinch | Hit.Flash,
			props.element,
			user:context(),
			Drag.None
		)
	)
	spell.on_update_func = function(self)
		if not self:current_tile():get_tile(Direction.Up, 1):is_edge() then
			self:current_tile():get_tile(Direction.Up, 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(Direction.Up, 1):attack_entities(self)
		end
		if not self:current_tile():get_tile(Direction.Down, 1):is_edge() then
			self:current_tile():get_tile(Direction.Down, 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(Direction.Down, 1):attack_entities(self)
		end
		self:current_tile():attack_entities(self)
	end

	spell.can_move_to_func = function(tile)
		return true
	end

	Resources.play_audio(AUDIO)

	return spell
end

function create_long_slash(user, props)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_tile_highlight(Highlight.Flash)
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Flinch | Hit.Flash,
			props.element,
			user:context(),
			Drag.None
		)
	)

	spell.on_update_func = function(self)
		if not self:current_tile():get_tile(user:facing(), 1):is_edge() then
			self:current_tile():get_tile(user:facing(), 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(user:facing(), 1):attack_entities(self)
		end
		self:current_tile():attack_entities(self)
	end

	spell.can_move_to_func = function(tile)
		return true
	end

	Resources.play_audio(AUDIO)

	return spell
end

function create_dream_slash(user, props)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_tile_highlight(Highlight.Flash)
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Flinch | Hit.Flash,
			props.element,
			user:context(),
			Drag.None
		)
	)
	spell.on_update_func = function(self)
		local tile = spell:current_tile()
		local tile2 = tile:get_tile(spell:facing(), 1)
		if tile then
			if tile:get_tile(Direction.Up, 1) and not tile:get_tile(Direction.Up, 1):is_edge() then
				tile:get_tile(Direction.Up, 1):set_highlight(Highlight.Flash)
				tile:get_tile(Direction.Up, 1):attack_entities(self)
			end
			if tile:get_tile(Direction.Down, 1) and not tile:get_tile(Direction.Down, 1):is_edge() then
				tile:get_tile(Direction.Down, 1):set_highlight(Highlight.Flash)
				tile:get_tile(Direction.Down, 1):attack_entities(self)
			end
		end

		if tile2 then
			if tile2:get_tile(Direction.Up, 1) and not tile2:get_tile(Direction.Up, 1):is_edge() then
				tile2:get_tile(Direction.Up, 1):set_highlight(Highlight.Flash)
				tile2:get_tile(Direction.Up, 1):attack_entities(self)
			end
			if tile2:get_tile(Direction.Down, 1) and not tile2:get_tile(Direction.Down, 1):is_edge() then
				tile2:get_tile(Direction.Down, 1):set_highlight(Highlight.Flash)
				tile2:get_tile(Direction.Down, 1):attack_entities(self)
			end
			if not tile2:is_edge() then
				tile2:set_highlight(Highlight.Flash)
				tile2:attack_entities(self)
			end
		end
		tile:attack_entities(self)
	end

	spell.can_move_to_func = function(tile)
		return true
	end

	Resources.play_audio(AUDIO)

	return spell
end

function create_sonic_slash(user, props)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_tile_highlight(Highlight.Flash)
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Flinch | Hit.Flash,
			props.element,
			user:context(),
			Drag.None
		)
	)
	local anim = spell:animation()
	spell:set_texture(SLASH_TEXTURE, true)
	anim:load("spell_sword_slashes.animation")
	anim:set_state("WIDE")
	spell.on_update_func = function(self)
		if not self:current_tile():get_tile(Direction.Up, 1):is_edge() then
			self:current_tile():get_tile(Direction.Up, 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(Direction.Up, 1):attack_entities(self)
		end
		if not self:current_tile():get_tile(Direction.Down, 1):is_edge() then
			self:current_tile():get_tile(Direction.Down, 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(Direction.Down, 1):attack_entities(self)
		end
		self:current_tile():attack_entities(self)
		if self:is_sliding() == false then
			if self:current_tile():is_edge() and self.slide_started then
				self:delete()
			end

			local dest = self:get_tile(spell:facing(), 1)
			local ref = self
			self:slide(dest, (4), (0),
				function()
					ref.slide_started = true
				end
			)
		end
	end
	spell.on_collision_func = function(self, other)
		self:delete()
	end
	spell.on_delete_func = function(self)
		self:erase()
	end
	spell.can_move_to_func = function(tile)
		return true
	end

	Resources.play_audio(AUDIO)

	return spell
end

function create_fighter_slash(user, props)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_tile_highlight(Highlight.Flash)
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Flinch | Hit.Flash,
			props.element,
			user:context(),
			Drag.None
		)
	)

	spell.on_update_func = function(self)
		if not self:current_tile():get_tile(user:facing(), 1):is_edge() then
			self:current_tile():get_tile(user:facing(), 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(user:facing(), 1):attack_entities(self)
		end
		if not self:current_tile():get_tile(user:facing(), 2):is_edge() then
			self:current_tile():get_tile(user:facing(), 2):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(user:facing(), 2):attack_entities(self)
		end
		self:current_tile():attack_entities(self)
	end

	spell.can_move_to_func = function(tile)
		return true
	end

	Resources.play_audio(AUDIO)

	return spell
end

function create_fire_slash(user, props)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_tile_highlight(Highlight.Flash)
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Flinch,
			Element.Fire,
			user:context(),
			Drag.None
		)
	)
	local anim = spell:animation()
	spell:set_texture(SLASH_TEXTURE, true)
	anim:load("spell_sword_slashes.animation")
	anim:set_state("FIRE")
	spell.on_update_func = function(self)
		if not self:current_tile():get_tile(Direction.Up, 1):is_edge() then
			self:current_tile():get_tile(Direction.Up, 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(Direction.Up, 1):attack_entities(self)
		end
		if not self:current_tile():get_tile(Direction.Down, 1):is_edge() then
			self:current_tile():get_tile(Direction.Down, 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(Direction.Down, 1):attack_entities(self)
		end
		self:current_tile():attack_entities(self)
		if self:is_sliding() == false then
			if self:current_tile():is_edge() and self.slide_started then
				self:delete()
			end

			local dest = self:get_tile(spell:facing(), 1)
			local ref = self
			self:slide(dest, (4), (0),
				function()
					ref.slide_started = true
				end
			)
		end
	end
	spell.on_collision_func = function(self, other)
		self:delete()
	end
	spell.on_delete_func = function(self)
		self:erase()
	end
	spell.can_move_to_func = function(tile)
		return true
	end

	Resources.play_audio(AUDIO)

	return spell
end

function create_aqua_slash(user, props)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_tile_highlight(Highlight.Flash)
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Flinch,
			Element.Aqua,
			user:context(),
			Drag.None
		)
	)
	local anim = spell:animation()
	spell:set_texture(SLASH_TEXTURE, true)
	anim:load("spell_sword_slashes.animation")
	anim:set_state("AQUA")
	spell.on_update_func = function(self)
		if not self:current_tile():get_tile(Direction.Up, 1):is_edge() then
			self:current_tile():get_tile(Direction.Up, 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(Direction.Up, 1):attack_entities(self)
		end
		if not self:current_tile():get_tile(Direction.Down, 1):is_edge() then
			self:current_tile():get_tile(Direction.Down, 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(Direction.Down, 1):attack_entities(self)
		end
		self:current_tile():attack_entities(self)
		if self:is_sliding() == false then
			if self:current_tile():is_edge() and self.slide_started then
				self:delete()
			end

			local dest = self:get_tile(spell:facing(), 1)
			local ref = self
			self:slide(dest, (4), (0),
				function()
					ref.slide_started = true
				end
			)
		end
	end
	spell.on_collision_func = function(self, other)
		self:delete()
	end
	spell.on_delete_func = function(self)
		self:erase()
	end
	spell.can_move_to_func = function(tile)
		return true
	end

	Resources.play_audio(AUDIO)

	return spell
end

function create_elec_slash(user, props)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_tile_highlight(Highlight.Flash)
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Flinch,
			Element.Elec,
			user:context(),
			Drag.None
		)
	)
	local anim = spell:animation()
	spell:set_texture(SLASH_TEXTURE, true)
	anim:load("spell_sword_slashes.animation")
	anim:set_state("ELEC")
	spell.on_update_func = function(self)
		if not self:current_tile():get_tile(Direction.Up, 1):is_edge() then
			self:current_tile():get_tile(Direction.Up, 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(Direction.Up, 1):attack_entities(self)
		end
		if not self:current_tile():get_tile(Direction.Down, 1):is_edge() then
			self:current_tile():get_tile(Direction.Down, 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(Direction.Down, 1):attack_entities(self)
		end
		self:current_tile():attack_entities(self)
		if self:is_sliding() == false then
			if self:current_tile():is_edge() and self.slide_started then
				self:delete()
			end

			local dest = self:get_tile(spell:facing(), 1)
			local ref = self
			self:slide(dest, (4), (0),
				function()
					ref.slide_started = true
				end
			)
		end
	end
	spell.on_collision_func = function(self, other)
		self:delete()
	end
	spell.on_delete_func = function(self)
		self:erase()
	end
	spell.can_move_to_func = function(tile)
		return true
	end

	Resources.play_audio(AUDIO)

	return spell
end

function create_wood_slash(user, props)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_tile_highlight(Highlight.Flash)
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Flinch,
			Element.Wood,
			user:context(),
			Drag.None
		)
	)
	local anim = spell:animation()
	spell:set_texture(SLASH_TEXTURE, true)
	anim:load("spell_sword_slashes.animation")
	anim:set_state("WOOD")
	spell.on_update_func = function(self)
		if not self:current_tile():get_tile(Direction.Up, 1):is_edge() then
			self:current_tile():get_tile(Direction.Up, 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(Direction.Up, 1):attack_entities(self)
		end
		if not self:current_tile():get_tile(Direction.Down, 1):is_edge() then
			self:current_tile():get_tile(Direction.Down, 1):set_highlight(Highlight.Flash)
			self:current_tile():get_tile(Direction.Down, 1):attack_entities(self)
		end
		self:current_tile():attack_entities(self)
		if self:is_sliding() == false then
			if self:current_tile():is_edge() and self.slide_started then
				self:delete()
			end

			local dest = self:get_tile(spell:facing(), 1)
			local ref = self
			self:slide(dest, (4), (0),
				function()
					ref.slide_started = true
				end
			)
		end
	end
	spell.on_collision_func = function(self, other)
		self:delete()
	end
	spell.on_delete_func = function(self)
		self:erase()
	end
	spell.can_move_to_func = function(tile)
		return true
	end

	Resources.play_audio(AUDIO)

	return spell
end
