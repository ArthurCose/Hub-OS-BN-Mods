local DAMAGE = 0

local AUDIO1 = Resources.load_audio("panelchange_final.ogg")
local AUDIO2 = Resources.load_audio("panelchange.ogg")
local AUDIO_DARKHOLE = Resources.load_audio("darkhole.ogg")



function create_dark_hole(user, tile)
	local TEXTURE = Resources.load_texture("Hole.png")
	local cube = Obstacle.new(Team.Other)
	cube:enable_sharing_tile(true)
	cube:enable_hitbox(false)
	cube:set_name("DarkHole")
	cube:set_health(0)
	cube:set_facing(user:facing())
	cube:set_texture(TEXTURE, true)
	cube:sprite():set_layer(10)
	local anim = cube:animation()
	anim:load("Hole.animation")
	anim:set_state("DEFAULT")
	anim:apply(cube:sprite())
	anim:set_playback(Playback.Loop)
	cube.on_spawn_func = function(self)
		local tile = cube:current_tile()
		if not tile:is_walkable() then
			cube:delete()
		end
		tile:set_state(TileState.Normal)
	end
	cube.can_move_to_func = function(tile)
		return false
	end
	cube.tile = nil
	cube.on_update_func = function(self)
		if self.tile == nil then self.tile = self:current_tile() end
		if self.tile:state() ~= TileState.Normal then self:delete() end
	end
	--[[local query = function(ent)
		return Obstacle.from(ent) ~= nil
	end
	if #tile:find_entities(query) == 0 and not tile:is_edge() then return cube end]]
	if not tile:is_edge() then return cube end
	return nil
end

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_IDLE")
	action:set_lockout(ActionLockout.new_sequence())
	action.on_execute_func = function(self, user)
		local tile_count = 0
		local other_tile_count = 0
		local field = user:field()
		local all_red_tiles = field:find_tiles(function(tile)
			if tile:team() == user:team() then
				tile_count = tile_count + 1
				return true
			end
			return false
		end)
		local all_blue_tiles = field:find_tiles(function(tile)
			if tile:team() ~= user:team() then
				other_tile_count = other_tile_count + 1
				return true
			end
			return false
		end)
		local dark_hole_query = function(hole)
			return hole and hole:name() == "DarkHole" and hole:animation():state() == "DEFAULT"
		end
		local k = 0
		local cooldown = 0
		local step1 = self:create_step()
		local do_once = true
		local is_reveal = false
		local other_tile_original_state_table = {}
		local dark_hole_list = {}
		local other_dark_hole = {}
		step1.on_update_func = function(self)
			if cooldown <= 0 then
				k = k + 1
				cooldown = 2
				if do_once then
					Resources.play_audio(AUDIO_DARKHOLE)
					do_once = false
					for i = 1, tile_count, 1 do
						local dark_hole = create_dark_hole(user, all_red_tiles[i])
						local dark_check = all_red_tiles[i]:find_obstacles(dark_hole_query)
						if dark_hole ~= nil and #dark_check <= 0 then
							all_red_tiles[i]:set_state(TileState.Normal); field:spawn(dark_hole, all_red_tiles[i]); table
									.insert(dark_hole_list, dark_hole)
						end
					end
					for j = 1, other_tile_count, 1 do
						--local dark_check = all_blue_tiles[j]:find_obstacles(dark_hole_query)
						table.insert(other_tile_original_state_table, all_blue_tiles[j]:state())
						--if #dark_check > 0 then table.insert(other_dark_hole) end
					end
				end
				Resources.play_audio(AUDIO2)
				if is_reveal then
					is_reveal = false
					for j = 1, other_tile_count, 1 do
						--[[local dark_check = all_blue_tiles[j]:find_obstacles(dark_hole_query)
						dark_check[j]:hide()]]
						all_blue_tiles[j]:set_state(other_tile_original_state_table[j])
					end
				else
					is_reveal = true
					for j = 1, other_tile_count, 1 do
						--[[local dark_check = all_blue_tiles[j]:find_obstacles(dark_hole_query)
						dark_check[j]:reveal()]]
						all_blue_tiles[j]:set_state(TileState.Poison)
					end
				end
			else
				cooldown = cooldown - 1
			end

			if k == 9 then
				Resources.play_audio(AUDIO1)
				self:complete_step()
			end
		end
	end
	return action
end
