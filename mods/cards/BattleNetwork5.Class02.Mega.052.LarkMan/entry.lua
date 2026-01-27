---@type BattleNetwork6.Libraries.ChipNavi
local ChipNaviLib = require("BattleNetwork6.Libraries.ChipNavi")

---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
local shadow_asset = bn_assets.load_texture("navi_shadow.png")

local NAVI_TEXTURE = bn_assets.load_texture("navi_larkman.png")
local NAVI_ANIM_PATH = bn_assets.fetch_animation_path("navi_larkman.animation")

local LARK_DRIVE_SFX = bn_assets.load_audio("lark_drive.ogg")
local appear_audio = bn_assets.load_audio("appear.ogg")
local confirm_chime = bn_assets.load_audio("confirm_chime.ogg")

---@param user Entity
---@param props CardProperties
function card_init(user, props)
	local action = Action.new(user)
	action:set_lockout(ActionLockout.new_sequence())
	action:create_step()

	---@type Entity
	local navi
	---@type Animation
	local navi_animation

	local previously_visible;

	local larkman_input_completed = false
	local larkman_input_index = 1
	local can_proceed = false

	local facing = user:facing()
	local facing_away = user:facing_away()

	local dest_list
	local dest_index = 1
	local anim_list = {
		{ "DIVE_DIAGONAL_UP",   false },
		{ "DIVE_DIAGONAL_UP",   false },
		{ "DIVE_DIAGONAL_UP",   false },
		{ "DIVE_DIAGONAL_DOWN", false },
		{ "DIVE_DIAGONAL_DOWN", true },
		{ "DIVE_DIAGONAL_UP",   true },
		{ "DIVE_DIAGONAL_UP",   true },
		{ "DIVE_DIAGONAL_UP",   true },
	}

	action.on_execute_func = function(self, user)
		previously_visible = user:sprite():visible()

		local spawn_tile = user:current_tile()

		dest_list = {
			spawn_tile:get_tile(Direction.join(Direction.Down, facing_away), 1),
			spawn_tile,
			spawn_tile:get_tile(Direction.join(facing, Direction.Up), 1),
			spawn_tile:get_tile(facing, 2),
			spawn_tile:get_tile(Direction.join(facing, Direction.Down), 1),
			spawn_tile,
			spawn_tile:get_tile(Direction.join(Direction.Up, facing_away), 1),
			spawn_tile:get_tile(Direction.join(Direction.Up, facing_away), 2)
		}

		-- Setup the navi's sprite and animation.
		-- Done separately from the actual state and texture assignments for a reason.
		-- We need this to be accessible by other local functions down below.
		navi = Artifact.new(user:team())

		local navi_sprite = navi:sprite()
		navi_animation = navi:animation()

		navi:set_facing(facing)
		navi_sprite:set_texture(NAVI_TEXTURE)
		navi_animation:load(NAVI_ANIM_PATH)

		navi_animation:set_state("CHARACTER_IDLE")

		navi:set_shadow(shadow_asset)
		navi:show_shadow(false)

		ChipNaviLib.swap_in(navi, user, function()
			Resources.play_audio(appear_audio)

			navi_animation:set_state("CHARACTER_IDLE", { { 1, 30 } })

			navi:show_shadow(true)

			local distance = 2
			local tele_direction = Direction.join(Direction.Down, facing_away)
			local teleport_tile = user:get_tile(tele_direction, distance)

			local attempts = 0
			while teleport_tile == nil and attempts < 5 do
				distance = distance - 1
				teleport_tile = user:get_tile(tele_direction, distance)
				attempts = attempts + 1
			end

			navi_animation:on_complete(function()
				can_proceed = true
				navi:hide()
				navi:teleport(teleport_tile)
			end)
		end)

		Field.spawn(navi, spawn_tile)
	end


	local larkman_input_timer = 6
	local can_start_moving = false
	local ending_action = false
	local lime = Color.new(0, 255, 0, 224)
	local color_component = user:create_component(Lifetime.Scene)
	color_component.on_update_func = function()
		if larkman_input_completed == false then return end
		navi:sprite():set_color(lime)
		navi:sprite():set_color_mode(ColorMode.Multiply)
	end

	local function create_and_spawn_spell(tile)
		if tile == nil then return end

		local wait = 0
		local spell = Spell.new(user:team())
		spell:set_hit_props(HitProps.from_card(props, user:context(), Drag.None))
		spell.on_update_func = function(self)
			if wait > 0 then
				wait = wait - 1
				return
			end

			self:attack_tile()
			self:erase()
		end

		spell.on_attack_func = function(self, other)
			local hit_particle = bn_assets.HitParticle.new("BREAK")
			local offset = other:movement_offset()

			hit_particle:set_offset(
				offset.x + math.random(-16, 16),
				offset.y + math.random(-32, 0)
			)

			Field.spawn(hit_particle, other:current_tile())
		end

		if larkman_input_completed == true then
			spell.on_spawn_func = function()
				local windbreaker = Spell.new(user:team())
				windbreaker:set_hit_props(
					HitProps.new(
						0,
						Hit.None,
						Element.Wind,
						user:context(),
						Drag.None
					)
				)
				windbreaker.on_update_func = function(self)
					self:attack_tile()
				end
			end

			wait = 1
		end
		Field.spawn(spell, tile)
	end

	action.on_update_func = function()
		-- if not larkman_input_completed and user:input_has(Input.Held.Shoot) then
		-- 	if (larkman_input_index == 1 and user:input_has(Input.Pressed.Up)) or (larkman_input_index == 2 and user:input_has(Input.Pressed.Right)) then
		-- 		larkman_input_index = larkman_input_index + 1
		-- 		larkman_input_timer = 6
		-- 	elseif (larkman_input_index == 3 and user:input_has(Input.Pressed.Down)) then
		-- 		larkman_input_completed = true

		-- 		Resources.play_audio(confirm_chime)
		-- 	else
		-- 		larkman_input_timer = larkman_input_timer - 1
		-- 	end

		-- 	if larkman_input_timer == 0 then
		-- 		larkman_input_index = 1
		-- 	end
		-- end

		if can_proceed == true then
			navi_animation:set_state("CHARACTER_IDLE")
			navi_animation:set_playback(Playback.Once)

			navi_animation:on_complete(function()
				navi_animation:set_state(anim_list[dest_index][1])
			end)

			can_proceed = false
			can_start_moving = true
		end

		if can_start_moving == true then
			if navi:is_moving() then return end

			if dest_index == #dest_list then
				if ending_action == false then
					ending_action = true

					ChipNaviLib.swap_in(user, navi, function()
						action:end_action()
					end)
				end

				return
			end

			local dest = dest_list[dest_index]

			while dest == nil do
				dest_index = dest_index + 1
				dest = dest_list[dest_index]
			end

			if dest_index == 1 then
				navi:reveal()
				Resources.play_audio(LARK_DRIVE_SFX)
			end

			if navi_animation:state() ~= anim_list[dest_index][1] then navi_animation:set_state(anim_list[dest_index][1]) end
			if anim_list[dest_index][2] == true then navi:set_facing(facing_away) else navi:set_facing(facing) end

			navi:slide(dest, 4, function()
				create_and_spawn_spell(dest)
				if dest_index == 4 then
					create_and_spawn_spell(dest:get_tile(Direction.Up, 1))
					create_and_spawn_spell(dest:get_tile(Direction.Down, 1))
				end

				dest_index = dest_index + 1
			end)
		end
	end


	action.on_action_end_func = function()
		if previously_visible ~= nil then
			if previously_visible then
				user:reveal()
			else
				user:hide()
			end
		end

		color_component:eject()

		if navi and not navi:deleted() then
			navi:erase()
		end
	end

	return action
end
