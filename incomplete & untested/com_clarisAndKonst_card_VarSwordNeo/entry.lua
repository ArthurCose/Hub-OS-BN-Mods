nonce = function() end

local DAMAGE = 220
local SLASH_TEXTURE = Resources.load_texture("spell_sword_slashes.png")
local BLADE_TEXTURE = Resources.load_texture("spell_sword_blades.png")
local DREAM_TEXTURE = Resources.load_texture("spell_dreamsword.png")
local AUDIO = Resources.load_audio("sfx.ogg")
local CROSS_AUDIO = Resources.load_audio("cross.ogg")
local SUCCESS_AUDIO = Resources.load_audio("input.ogg", true)





local recipes = {
	{
		name = "cross",
		pattern = {
			{ "down" },
			{ "right" },
			{ "up" }
		}
	},
	{
		name = "super sonic",
		pattern = {
			{ "left" },
			{ "right" },
			{ "left" },
			{ "b" }
		}
	},
	{
		name = "twin dream",
		pattern = {
			{ "up" },
			{ "b" },
			{ "down" },
			{ "b" },
			{ "up" },
			{ "b" },
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



		if attack_name == "cross" then
			take_cross_action(actor, props)
		elseif attack_name == "super sonic" then
			take_super_action(actor, props)
		elseif attack_name == "twin dream" then
			take_dream_action(actor, props)
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

function take_cross_action(actor, props)
	local action = Action.new(actor, "PLAYER_SWORD")
	local field = actor:field()
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
		local sword = create_cross_slash(actor, props)
		local sword2 = create_cross_slash(actor, props)
		local tile = actor:get_tile(actor:facing(), 1)
		local props2 = sword:copy_hit_props()
		props2.damage = props.damage * 2
		sword2:set_hit_props(props2)

		local sharebox1 = SharedHitbox.new(sword, 9)
		sharebox1:set_hit_props(sword:copy_hit_props())

		local sharebox2 = SharedHitbox.new(sword, 9)
		sharebox2:set_hit_props(sword:copy_hit_props())

		local sharebox3 = SharedHitbox.new(sword, 9)
		sharebox3:set_hit_props(sword:copy_hit_props())

		local sharebox4 = SharedHitbox.new(sword, 9)
		sharebox4:set_hit_props(sword:copy_hit_props())

		local hitboxbox5 = SharedHitbox.new(sword, 9)
		sharebox4:set_hit_props(sword:copy_hit_props())

		field:spawn(sword2, tile)

		field:spawn(sharebox1, tile:get_tile(Direction.UpLeft, 1))
		field:spawn(sharebox2, tile:get_tile(Direction.DownLeft, 1))
		field:spawn(sharebox3, tile:get_tile(Direction.UpRight, 1))
		field:spawn(sharebox4, tile:get_tile(Direction.DownRight, 1))

		local fx = Artifact.new()
		fx:set_facing(sword:facing())
		actor:field():spawn(fx, tile)
		local anim = fx:animation()
		fx:set_texture(SLASH_TEXTURE)
		anim:load("spell_sword_slashes.animation")
		anim:set_state("CROSS")
		anim:on_complete(function()
			fx:erase()
			sword:erase()
			sword2:erase()
		end)
	end)
	actor:queue_action(action)
	Resources.play_audio(CROSS_AUDIO)
end

function take_super_action(actor, props)
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
		actor:queue_action(action2)
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

function create_cross_slash(user, props)
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
		if not self:current_tile():is_edge() then
			self:current_tile():set_highlight(Highlight.Flash)
		end
		if spell:current_tile():get_tile(Direction.UpLeft, 1) and not spell:current_tile():get_tile(Direction.UpLeft, 1):is_edge() then
			spell:current_tile():get_tile(Direction.UpLeft, 1):set_highlight(Highlight.Flash)
		end
		if spell:current_tile():get_tile(Direction.DownLeft, 1) and not spell:current_tile():get_tile(Direction.DownLeft, 1):is_edge() then
			spell:current_tile():get_tile(Direction.DownLeft, 1):set_highlight(Highlight.Flash)
		end
		if spell:current_tile():get_tile(Direction.UpRight, 1) and not spell:current_tile():get_tile(Direction.UpRight, 1):is_edge() then
			spell:current_tile():get_tile(Direction.UpRight, 1):set_highlight(Highlight.Flash)
		end
		if spell:current_tile():get_tile(Direction.DownRight, 1) and not spell:current_tile():get_tile(Direction.DownRight, 1):is_edge() then
			spell:current_tile():get_tile(Direction.DownRight, 1):set_highlight(Highlight.Flash)
		end
		self:current_tile():attack_entities(self)
	end

	spell.can_move_to_func = function(tile)
		return true
	end

	return spell
end

function create_dream_slash(user, props)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_tile_highlight(Highlight.Flash)
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Flinch,
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
	spell.on_delete_func = function(self)
		self:erase()
	end
	spell.can_move_to_func = function(tile)
		return true
	end

	Resources.play_audio(AUDIO)

	return spell
end
