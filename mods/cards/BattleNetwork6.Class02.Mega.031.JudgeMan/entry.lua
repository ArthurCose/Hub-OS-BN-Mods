---@type BattleNetwork6.Libraries.ChipNavi
local ChipNaviLib = require("BattleNetwork6.Libraries.ChipNavi")

---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local NAVI_TEXTURE = bn_assets.load_texture("navi_judgeman.png")
local NAVI_ANIM_PATH = bn_assets.fetch_animation_path("navi_judgeman.animation")

local ATTACK_AUDIO = bn_assets.load_audio("judgeman_whip.ogg")
local IMPACT_AUDIO = bn_assets.load_audio("thunder2.ogg")
local APPEAR_AUDIO = bn_assets.load_audio("appear.ogg")

---@param actor Entity
---@param props CardProperties
function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_MOVE")

	local book_damage = 20
	for _, tag in ipairs(props.tags) do
		if tag == "BOOK_DAMAGE_40" then book_damage = 40 end
		if tag == "BOOK_DAMAGE_60" then book_damage = 60 end
	end

	if props.boosted_damage >= props.damage * 2 then book_damage = book_damage * 2 end

	action:override_animation_frames({ { 1, 2 }, { 2, 2 }, { 3, 2 } })

	action:set_lockout(ActionLockout.new_sequence())
	action:create_step()

	---@type Entity
	local navi
	---@type Animation
	local navi_animation

	local end_timer_started = false
	local end_timer = 50

	local previously_visible;

	action.on_execute_func = function(self, user)
		previously_visible = user:sprite():visible()

		local stolen_tiles = Field.find_tiles(function(tile)
			if tile:original_team() ~= user:team() or tile:team() == tile:original_team() then return false end

			if #tile:find_obstacles(function()
						return true
					end) > 0 then
				return false
			end

			if #tile:find_characters(function()
						return true
					end) > 0 then
				return false
			end

			return true
		end)

		local direction = user:facing()

		-- Setup the navi's sprite and animation.
		-- Done separately from the actual state and texture assignments for a reason.
		-- We need this to be accessible by other local functions down below.
		navi = Artifact.new(user:team())

		local navi_sprite = navi:sprite()
		navi_animation = navi:animation()

		navi:set_facing(direction)
		navi_sprite:set_texture(NAVI_TEXTURE)
		navi_animation:load(NAVI_ANIM_PATH)

		local function spawn_hitbox(tile)
			if not tile then return end

			local spell = Spell.new(user:team())
			spell:set_hit_props(
				HitProps.from_card(props, user:context())
			)

			spell.on_update_func = function(self)
				self:attack_tile()
				self:erase()
			end

			Field.spawn(spell, tile)
		end

		local list_of_books = {}
		local deleted_books = {}

		local get_book_direction = function(book, target)
			if not book then return Direction.None end
			if not target then return Direction.None end

			local book_tile = book:current_tile()
			local goal_tile = target:current_tile()

			if book_tile == goal_tile then
				return Direction.None
			end

			local book_direction = Direction.None

			local book_pos = { x = book_tile:x(), y = book_tile:y() }
			local goal_pos = { x = goal_tile:x(), y = goal_tile:y() }

			local difference_x = math.abs(book_pos.x - goal_pos.x)
			local difference_y = math.abs(book_pos.y - goal_pos.y)

			if difference_x > difference_y then
				if book_pos.x > goal_pos.x then
					book_direction = Direction.Left
				else
					book_direction = Direction.Right
				end
			elseif difference_y > difference_x then
				if book_pos.y > goal_pos.y then
					book_direction = Direction.Up
				else
					book_direction = Direction.Down
				end
			elseif difference_y == difference_x then
				local dirs = {}
				if book_pos.x > goal_pos.x then
					table.insert(dirs, Direction.Left)
				else
					table.insert(dirs, Direction.Right)
				end

				if book_pos.y > goal_pos.y then
					table.insert(dirs, Direction.Up)
				else
					table.insert(dirs, Direction.Down)
				end

				book_direction = dirs[math.random(1, #dirs)]
			end

			return book_direction
		end

		local function spawn_book(tile)
			if not tile or not tile:is_walkable() then return end

			local book = Spell.new(user:team())

			book:set_hit_props(
				HitProps.new(
					book_damage,
					Hit.None,
					Element.None,
					user:context(),
					Drag.None
				)
			)

			local book_sprite = book:sprite()

			book_sprite:copy_from(navi_sprite)

			local book_anim = book:animation()

			book_anim:copy_from(navi_animation)

			book:set_facing(user:facing())

			book_anim:set_state("BOOK_SPAWN")

			book.on_spawn_func = function(self)
				Field.reclaim_column(tile:x(), tile:original_team())
				table.insert(list_of_books, self)
			end

			book.on_delete_func = function(self)
				table.insert(deleted_books, self)
				self:erase()
			end

			local change_timer = 999
			book_anim:on_complete(function()
				change_timer = 5
			end)

			local entity_list = Field.find_nearest_characters(user, function(e)
				return e:team() ~= user:team()
			end)

			local target = entity_list[1]

			local function poof_away()
				local artifact = bn_assets.MobMove.new("MEDIUM_START")
				local offset = book:movement_offset()
				artifact:set_offset(offset.x, offset.y)
				Field.spawn(artifact, book:current_tile())
				book:delete()
			end

			book.on_update_func = function(self)
				if change_timer > 0 then
					change_timer = change_timer - 1
					return
				elseif change_timer == 0 then
					self:animation():set_state("BOOK_BITE")
					self:animation():set_playback(Playback.Loop)

					change_timer = -1
					return
				end

				if not book:current_tile():is_walkable() then
					poof_away()
					return
				end

				self:attack_tile()

				if not self:is_sliding() then
					local dir = get_book_direction(self, target)

					if dir == Direction.None then
						poof_away()
						return
					end

					local next_tile = self:get_tile(dir, 1)

					if not next_tile then
						self:delete()
						return
					end

					self:slide(next_tile, 20)
				end
			end

			book.on_collision_func = function(self)
				local particle = bn_assets.HitParticle.new("SPARK_1", math.random(-16, 16), 0)
				Field.spawn(particle, self:current_tile())
				self:delete()
			end

			Field.spawn(book, tile)
		end

		local spawn_tile = user:current_tile()
		local whip = navi:sprite():create_node()

		whip:copy_from(navi:sprite())
		whip:hide()

		local whip_animation = Animation.new()
		whip_animation:copy_from(navi_animation)

		ChipNaviLib.swap_in(navi, user, function()
			navi_animation:set_state("CHARACTER_IDLE")

			navi_animation:on_complete(function()
				navi_animation:set_state("WHIP_START")

				whip:reveal()

				whip_animation:set_state("WHIP")

				navi_animation:on_complete(function()
					navi_animation:set_state("WHIP_HOLD", { { 1, 30 } })
					navi_animation:set_playback(Playback.Loop)

					whip_animation:set_state("WHIP_ACTIVE", {
						{ 1, 3 }, { 2, 3 }, { 1, 3 }, { 2, 3 }, { 1, 3 }, { 2, 3 },
						{ 1, 3 }, { 2, 3 }, { 1, 3 }, { 2, 3 }
					})
					whip_animation:set_playback(Playback.Loop)

					navi_animation:on_frame(1, function()
						Resources.play_audio(ATTACK_AUDIO)

						for x = 1, 3, 1 do
							spawn_hitbox(Field.tile_at(spawn_tile:x() + x, spawn_tile:y()))
						end
					end, true)

					navi_animation:on_complete(function()
						navi_animation:set_state("CHARACTER_IDLE")
						whip:hide()

						if #stolen_tiles == 0 then
							end_timer_started = true
						else
							navi_animation:set_state("SUMMON_START")
							navi_animation:on_frame(1, function()
								Resources.play_audio(APPEAR_AUDIO)

								for i = 1, #stolen_tiles, 1 do
									spawn_book(stolen_tiles[i])
								end
							end, true)
						end
					end)
				end)
			end)
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
			if whip:visible() then
				whip_animation:update()
				whip_animation:apply(whip)
			end

			if #list_of_books > 0 and #list_of_books == #deleted_books then end_timer_started = true end

			if not end_timer_started then
				return
			end

			end_timer = end_timer - 1

			if end_timer == 0 then
				ChipNaviLib.swap_in(user, navi, function()
					action:end_action()
				end)
			end
		end
	end


	return action
end
