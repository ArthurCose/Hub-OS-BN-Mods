---@type BattleNetwork6.Libraries.ChipNavi
local ChipNaviLib = require("BattleNetwork6.Libraries.ChipNavi")

---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local NAVI_TEXTURE = bn_assets.load_texture("navi_elementman.png")
local NAVI_ANIM_PATH = bn_assets.fetch_animation_path("navi_elementman.animation")

local NAVI_PALETTE_NULL = bn_assets.load_texture("palette_elementman_null.png")
local NAVI_PALETTE_FIRE = bn_assets.load_texture("palette_elementman_fire.png")
local NAVI_PALETTE_WOOD = bn_assets.load_texture("palette_elementman_wood.png")
local NAVI_PALETTE_ELEC = bn_assets.load_texture("palette_elementman_elec.png")
local NAVI_PALETTE_AQUA = bn_assets.load_texture("palette_elementman_aqua.png")

local FIRE_SPELL_TEXTURE = bn_assets.load_texture("meteor.png")
local AQUA_SPELL_TEXTURE = bn_assets.load_texture("battle_shine.png")
local ELEC_SPELL_TEXTURE = bn_assets.load_texture("bn3_lightning.png")
local WOOD_SPELL_TEXTURE = bn_assets.load_texture("wood_tower.png")
local RING_EXPLOSION_TEXTURE = bn_assets.fetch_animation_path("ring_explosion.png")

local FIRE_SPELL_ANIM_PATH = bn_assets.fetch_animation_path("meteor.animation")
local AQUA_SPELL_ANIM_PATH = bn_assets.fetch_animation_path("battle_shine.animation")
local ELEC_SPELL_ANIM_PATH = bn_assets.fetch_animation_path("bn3_lightning.animation")
local WOOD_SPELL_ANIM_PATH = bn_assets.fetch_animation_path("wood_tower.animation")
local RING_EXPLOSION_ANIM_PATH = bn_assets.fetch_animation_path("ring_explosion.animation")

local FIRE_ATTACK_AUDIO = bn_assets.load_audio("meteor_land.ogg")
local ELEC_ATTACK_AUDIO = bn_assets.load_audio("elementman_thunder.ogg")
local WOOD_ATTACK_AUDIO = bn_assets.load_audio("wood_tower.ogg")
local COLOR_CHANGE_AUDIO = bn_assets.load_audio("colorpoint_buzz.ogg")
local SET_GRASS_AUDIO = bn_assets.load_audio("grass.ogg")
local SET_ICE_AUDIO = bn_assets.load_audio("panel_change_finish.ogg")

local APPEAR_AUDIO = bn_assets.load_audio("appear.ogg")

---@param user Entity
---@param props CardProperties
function card_init(user, props)
	local action = Action.new(user, "CHARACTER_MOVE")

	action:override_animation_frames({ { 1, 2 }, { 2, 2 }, { 3, 2 } })

	action:set_lockout(ActionLockout.new_sequence())
	action:create_step()

	---@type Entity
	local navi
	---@type Animation
	local navi_animation

	local direction

	local end_timer_started = false
	local end_timer = 50

	local cycles = 0

	local attacked = false
	local spell_created = false
	local color_selected = false
	local previously_visible = true
	local start_changing_color = false

	local element = Element.None
	local element_list = { Element.Fire, Element.Aqua, Element.Elec, Element.Wood }
	local palette_list = { NAVI_PALETTE_FIRE, NAVI_PALETTE_AQUA, NAVI_PALETTE_ELEC, NAVI_PALETTE_WOOD }
	local list_index = 1

	local original_timer = 16

	local name = props.short_name

	if string.find(name, "\u{e000}") then
		original_timer = 14
	elseif string.find(name, "\u{e001}") then
		original_timer = 12
	end

	local function create_lightning(tiles, index)
		local tile = tiles[index]

		local spell = Spell.new(user:team())
		local spell_anim = spell:animation()

		spell:set_texture(ELEC_SPELL_TEXTURE)
		spell_anim:load(ELEC_SPELL_ANIM_PATH)
		spell_anim:set_state("DEFAULT")
		spell:set_hit_props(
			HitProps.new(
				props.damage,
				props.hit_flags,
				Element.Elec,
				user:context(),
				Drag.None
			)
		)

		spell_anim:on_complete(function()
			spell:hide()
		end)

		local spawn_delay = 30

		spell.on_spawn_func = function()
			Resources.play_audio(ELEC_ATTACK_AUDIO)
			if tile:can_set_state(TileState.Broken) then tile:set_state(TileState.Broken) end
		end

		spell.on_update_func = function(self)
			self:attack_tile()
			spawn_delay = spawn_delay - 1
			if spawn_delay > 0 then return end
			self:delete()
		end

		spell.on_delete_func = function(self)
			index = index + 1

			if index > #tiles then
				end_timer_started = true
				return
			end
			Field.spawn(create_lightning(tiles, index), tiles[index])

			self:erase()
		end

		return spell
	end

	local function create_impact_explosion(tile, team)
		local explosion = Spell.new(team)
		explosion:set_texture(RING_EXPLOSION_TEXTURE)

		local new_anim = explosion:animation()
		new_anim:load(RING_EXPLOSION_ANIM_PATH)
		new_anim:set_state("DEFAULT")

		explosion:sprite():set_layer(-2)

		Resources.play_audio(FIRE_ATTACK_AUDIO)

		explosion.on_spawn_func = function()
			Field.shake(5, 18)
		end

		Field.spawn(explosion, tile)

		new_anim:on_complete(function()
			explosion:erase()
		end)
	end

	local function create_meteor(player)
		local meteor = Spell.new(player:team())

		meteor:set_tile_highlight(Highlight.Flash)
		meteor:set_facing(player:facing())

		meteor:set_hit_props(
			HitProps.new(
				props.damage,
				props.hit_flags,
				Element.Fire,
				user:context(),
				Drag.None
			)
		)

		meteor:set_texture(FIRE_SPELL_TEXTURE)

		local anim = meteor:animation()
		anim:load(FIRE_SPELL_ANIM_PATH)
		anim:set_state("DEFAULT")
		meteor:sprite():set_layer(-2)

		local vel_x = 14
		local vel_y = 14

		if player:facing() == Direction.Left then
			vel_x = -vel_x
		end

		meteor:set_offset(-vel_x * 8, -vel_y * 8)

		meteor.on_update_func = function(self)
			local offset = self:offset()
			if offset.y < 0 then
				self:set_offset(offset.x + vel_x, offset.y + vel_y)
				return
			end

			local tile = self:current_tile()

			if tile:is_walkable() then
				self:attack_tile()
				create_impact_explosion(tile, self:team())
			end

			self:delete()
		end

		meteor.on_delete_func = function(self)
			end_timer_started = true
			self:erase()
		end

		return meteor
	end

	local color_timer = 999
	local can_select_color = false

	action.on_execute_func = function(self, user)
		previously_visible = user:sprite():visible()

		direction = user:facing()

		-- Setup the navi's sprite and animation.
		-- Done separately from the actual state and texture assignments for a reason.
		-- We need this to be accessible by other local functions down below.
		navi = Artifact.new(user:team())

		local navi_sprite = navi:sprite()
		navi_animation = navi:animation()

		local wheel = navi_sprite:create_node()
		local wheel_animation = Animation.new()


		navi:set_facing(direction)
		navi_sprite:set_texture(NAVI_TEXTURE)
		navi_animation:load(NAVI_ANIM_PATH)
		navi:set_palette(NAVI_PALETTE_NULL)

		wheel:copy_from(navi_sprite)

		wheel_animation:copy_from(navi_animation)

		wheel:set_palette(navi:palette())

		wheel:hide()
		wheel:set_layer(2)

		local function create_tower()
			local start_ending = false

			local spell = Spell.new(user:team())
			spell:set_facing(user:facing())
			spell:set_hit_props(
				HitProps.new(
					props.damage,
					props.hit_flags,
					Element.Wood,
					user:context(),
					Drag.None
				)
			)

			spell:set_texture(WOOD_SPELL_TEXTURE)

			spell:set_offset(0, 6)

			local spell_anim = spell:animation()
			spell_anim:load(WOOD_SPELL_ANIM_PATH)

			spell_anim:set_state("SPAWN")

			-- spawn chaining is just to spawn it at the next tile ahead
			local SPAWN_DELAY = 16

			local spawn_counter = 0

			spell.on_update_func = function(self)
				spawn_counter = spawn_counter + 1

				-- stop chaining if this tile is broken or a hole
				local cur_tile = self:current_tile()
				if cur_tile and (cur_tile:state() == TileState.Broken or cur_tile:state() == TileState.PermaHole) then
					return
				end

				if spawn_counter == SPAWN_DELAY then
					local tile = self:current_tile():get_tile(self:facing(), 1)

					-- also stop if the next tile is broken or a hole
					if tile and tile:is_walkable() and tile:state() ~= TileState.Broken and tile:state() ~= TileState.PermaHole then
						local new = create_tower()

						Field.spawn(new, tile)
					else
						start_ending = true
					end
				end

				self:attack_tile()
			end

			spell.can_move_to_func = function(tile)
				return true
			end

			spell_anim:on_complete(function()
				spell_anim:set_state("LOOP")
				spell_anim:set_playback(Playback.Loop)

				local i = 0

				spell_anim:on_complete(function()
					i = i + 1

					if i < 4 then
						return
					end

					spell_anim:set_state("DESPAWN")
					spell_anim:on_complete(function()
						end_timer_started = start_ending

						spell:erase()
					end)
				end)
			end)

			spell.on_spawn_func = function()
				Resources.play_audio(WOOD_ATTACK_AUDIO)
			end

			return spell
		end

		local function create_attack()
			if element == Element.Fire then
				if attacked == false then
					Field.find_nearest_characters(user, function(character)
						if character:team() ~= user:team() then
							local destination_tile = character:current_tile()
							Field.spawn(create_meteor(user), destination_tile)
						end
						return false
					end)

					attacked = true
				end
			elseif element == Element.Aqua then
				local tiles = {
					user:get_tile(Direction.join(direction, Direction.Up), 1),
					user:get_tile(direction, 1),
					user:get_tile(Direction.join(direction, Direction.Down), 1)
				}

				if attacked == false then
					attacked = true
					for i = 1, #tiles, 1 do
						local tile = tiles[i]
						if tile == nil then goto continue end
						if tile:is_edge() then goto continue end

						local spell = Spell.new(user:team())
						local spell_anim = spell:animation()

						spell:set_texture(AQUA_SPELL_TEXTURE)

						spell_anim:load(AQUA_SPELL_ANIM_PATH)
						spell_anim:set_state("SHINE_LONG")

						props.hit_flags = props.hit_flags | Hit.Freeze
						props.status_durations[Hit.Freeze] = Hit.duration_for(Hit.Freeze, 1)

						spell:set_hit_props(
							HitProps.new(
								props.damage,
								props.hit_flags,
								Element.Aqua,
								user:context(),
								Drag.None
							)
						)

						tile:set_state(TileState.Ice)

						spell.on_spawn_func = function()
							Resources.play_audio(SET_ICE_AUDIO, AudioBehavior.NoOverlap)
						end

						spell_anim:on_complete(function()
							spell:delete()
						end)

						spell.on_update_func = function(self)
							self:attack_tile()
						end

						spell.on_delete_func = function(self)
							end_timer_started = true
							self:erase()
						end

						Field.spawn(spell, tile)

						::continue::
					end
				end
			elseif element == Element.Elec then
				local destination_tile = user:get_tile(direction, 3)

				if destination_tile == nil or destination_tile:is_edge() then
					end_timer_started = true
					return
				end

				local tiles = {}

				local x = destination_tile:x()

				for y = 0, Field.height() - 1, 1 do
					local tile = Field.tile_at(x, y)
					if not tile or tile:is_edge() then goto continue end

					table.insert(tiles, tile)

					::continue::
				end

				if attacked == false then
					Field.spawn(create_lightning(tiles, 1), tiles[1])
					attacked = true
				end
			elseif element == Element.Wood then
				Field.find_tiles(function(tile)
					if tile:is_walkable() then
						tile:set_state(TileState.Grass)
						Resources.play_audio(SET_GRASS_AUDIO, AudioBehavior.NoOverlap)
					end

					return false
				end)

				if attacked == false then
					Field.spawn(create_tower(), user:get_tile(direction, 1))
					attacked = true
				end
			end
		end

		local spawn_tile = user:current_tile()

		wheel_animation:set_state("WHEEL_MOVE", { { 4, 1 }, { 3, 1 }, { 2, 1 }, { 1, 1 } })
		wheel:reveal()

		ChipNaviLib.swap_in(navi, user, function()
			Resources.play_audio(APPEAR_AUDIO)

			if not navi:current_tile():is_walkable() then
				-- fail if navi is on a hole tile
				ChipNaviLib.swap_in(user, navi, function()
					action:end_action()
				end)

				return
			end

			navi_animation:set_state("CHARACTER_IDLE")
			wheel_animation:set_state("WHEEL_IDLE")
			wheel_animation:set_playback(Playback.Loop)
			wheel:set_palette(navi:palette())

			color_timer = original_timer

			start_changing_color = true
		end)

		Field.spawn(navi, spawn_tile)

		action.on_action_end_func = function()
			if previously_visible then
				user:reveal()
			else
				user:hide()
			end

			if navi and not navi:deleted() then
				navi:erase()
			end
		end

		action.on_update_func = function()
			if wheel:visible() then
				wheel_animation:update()
				wheel_animation:apply(wheel)
			end

			if start_changing_color == false then return end

			if not color_selected then
				if cycles == 20 then
					list_index = math.random(1, 4)
					color_timer = 0
				end

				color_timer = color_timer - 1

				if color_timer == 4 then Resources.play_audio(COLOR_CHANGE_AUDIO) end

				if color_timer == 0 then
					color_timer = original_timer
					navi:set_palette(palette_list[list_index])
					wheel:set_palette(navi:palette())
					element = element_list[list_index]

					list_index = list_index + 1
					if list_index > 4 then list_index = 1 end

					cycles = cycles + 1

					can_select_color = true
				end
			end

			if not color_selected and can_select_color and user:input_has(Input.Pressed.Use) then
				color_selected = true
			end

			if color_selected and not spell_created then
				navi_animation:set_state("ARMS_RAISE")

				wheel_animation:set_state("WHEEL_RAISE")
				wheel_animation:set_playback(Playback.Once)
				wheel_animation:update()

				wheel_animation:apply(wheel)

				navi_animation:on_complete(function()
					navi_animation:set_state("ARMS_LOOP")

					wheel_animation:set_state("WHEEL_LOOP")
					wheel_animation:update()

					wheel_animation:apply(wheel)

					navi_animation:on_complete(function()
						navi_animation:set_state("ARMS_SWING")

						wheel_animation:set_state("WHEEL_SWING")

						wheel_animation:update()
						wheel_animation:apply(wheel)

						navi_animation:on_complete(function()
							create_attack()
						end)
					end)
				end)
				spell_created = true
			end

			if not end_timer_started then return end

			end_timer = end_timer - 1

			if end_timer == 0 then
				wheel_animation:set_state("WHEEL_MOVE", { { 1, 1 }, { 2, 1 }, { 3, 1 } })
				ChipNaviLib.swap_in(user, navi, function()
					action:end_action()
				end)
			end
		end
	end

	return action
end
