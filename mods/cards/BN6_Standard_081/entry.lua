local bn_assets = require("BattleNetwork.Assets")

---@type SwordLib
local SwordLib = require("dev.konstinople.library.sword")

local sword = SwordLib.new_sword()
sword:set_default_blade_texture(bn_assets.load_texture("sword_blades.png"))
sword:set_default_blade_animation_path(bn_assets.fetch_animation_path("sword_blades.animation"))

local SLASH_TEXTURE = bn_assets.load_texture("sword_slashes.png")
local SLASH_ANIM_PATH = bn_assets.fetch_animation_path("sword_slashes.animation")

local AUDIO = bn_assets.load_audio("sword.ogg")
local DREAM_AUDIO = bn_assets.load_audio("lifesword.ogg")

local SUCCESS_AUDIO = bn_assets.load_audio("confirm_chime.ogg")

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
			{ "down", "left" },
			{ "down" },
			{ "down", "right" },
			{ "right" }
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

	local remaining_time = 46 -- frame timer

	local step1 = action:create_step()
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

	local step2 = action:create_step()
	step2.on_update_func = function()
		local attack_name = get_first_completed_recipe(matching)

		local sword_action = sword:create_action(actor, function()
			spawn_attack(actor, props, "DEFAULT", { {} })

			Resources.play_audio(AUDIO)
		end)

		if attack_name == "wide" then
			sword_action = sword:create_action(actor, function()
				spawn_attack(actor, props, "WIDE",
					{
						{ x = 0, y = -1 },
						{ x = 0, y = 1 }
					}
				)

				Resources.play_audio(AUDIO)
			end)
		elseif attack_name == "sonic" then
			sword_action = sword:create_action(actor, function()
				spawn_attack(actor, props, "SONIC",
					{
						{ x = 0, y = -1 },
						{ x = 0, y = 1 }
					},
					true, false
				)

				Resources.play_audio(AUDIO)
			end)
		elseif attack_name == "long" then
			sword_action = sword:create_action(actor, function()
				spawn_attack(actor, props, "LONG",
					{
						{ x = 1, y = 0 }
					}
				)

				Resources.play_audio(AUDIO)
			end)
		elseif attack_name == "dream" then
			sword_action = sword:create_action(actor, function()
				spawn_attack(actor, props, "DREAM",
					{
						{ x = 0, y = -1 },
						{ x = 0, y = 1 },
						{ x = 1, y = -1 },
						{ x = 1, y = 0 },
						{ x = 1, y = 1 },
					}
				)

				Resources.play_audio(DREAM_AUDIO)
			end)
		elseif attack_name == "fighter" then
			sword_action = sword:create_action(actor, function()
				spawn_attack(actor, props, "BIG", {
					{ x = 1, y = 0 },
					{ x = 2, y = 0 }
				})

				Resources.play_audio(AUDIO)
			end)
		end

		actor:queue_action(sword_action)
		step2:complete_step()
	end


	return action
end

function spawn_attack(user, props, state, offset_list, is_slide, is_pierce)
	if is_slide == nil then is_slide = false end
	if is_pierce == nil then is_pierce = false end

	local field = user:field()

	local slash = Spell.new(user:team())
	slash:set_facing(user:facing())

	slash:set_hit_props(
		HitProps.from_card(
			props,
			user:context(),
			Drag.None
		)
	)

	slash:set_texture(SLASH_TEXTURE)

	local anim = slash:animation()

	anim:load(SLASH_ANIM_PATH)
	anim:set_state(state)

	slash._is_slide = is_slide
	slash._is_pierce = is_pierce
	slash._offset_list = offset_list
	slash._has_slid = false

	if is_slide == true then
		anim:set_playback(Playback.Loop)
	else
		anim:on_complete(function()
			slash:delete()
		end)
	end

	slash.can_move_to_func = function(tile)
		if slash._is_pierce == true then return true end
		return slash._is_slide;
	end

	slash.on_update_func = function(self)
		local own_tile = self:current_tile()

		self:attack_tile()

		if #self._offset_list > 1 then
			for index, value in ipairs(self._offset_list) do
				local facing = self:facing()

				if value.x < 0 then facing = self:facing_away() end

				local attack_tile = own_tile:get_tile(facing, math.abs(value.x))

				if attack_tile ~= nil then
					self:attack_tile(attack_tile)
				end

				if value.y < 0 then
					facing = Direction.Up
				else
					facing = Direction.Down
				end
				if attack_tile ~= nil then
					attack_tile = attack_tile:get_tile(facing, math.abs(value.y))
					self:attack_tile(attack_tile)
				end
			end
		end

		if own_tile:is_edge() then return self:delete() end

		if self._is_slide == true and self:is_sliding() == false then
			self:slide(own_tile:get_tile(self:facing(), 1), 4, function()
				self._has_slid = true
			end)
		elseif self._is_slide == false and not self:is_sliding() and self._has_slid == true then
			self:delete()
		end
	end

	slash.on_collision_func = function(self, other)
		if self._is_pierce ~= true then
			self._is_slide = false
		end
		if self._is_slide == true then self:delete() end
	end

	slash.on_delete_func = function(self)
		self:erase()
	end

	field:spawn(slash, user:get_tile(user:facing(), 1))
end
