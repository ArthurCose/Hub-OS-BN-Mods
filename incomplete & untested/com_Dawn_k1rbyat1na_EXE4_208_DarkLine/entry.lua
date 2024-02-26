local DAMAGE = 0

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
	local action = Action.new(actor, "PLAYER_IDLE")
	action:set_lockout(ActionLockout.new_sequence())
	action.on_execute_func = function(self, user)
		local step1 = self:create_step()
		local direction = user:facing()
		local field = user:field()
		local self_tile = user:current_tile()
		local X = self_tile:x()
		local Y = self_tile:y()
		local dark_hole_query = function(hole)
			return hole and hole:name() == "DarkHole" and hole:animation():state() == "DEFAULT"
		end
		local k = 0
		local do_once = true
		step1.on_update_func = function(self)
			k = k + 1
			if do_once then
				Resources.play_audio(AUDIO_DARKHOLE)
				do_once = false
				for o = 1, 6, 1 do
					local desired_tile = field:tile_at(o, Y)
					local dark_check = desired_tile:find_obstacles(dark_hole_query)
					if not desired_tile:is_edge() and #dark_check <= 0 then
						local dark_hole = create_dark_hole(user, desired_tile)
						desired_tile:set_state(TileState.Normal)
						field:spawn(dark_hole, desired_tile)
					end
				end
			end
			if k == 50 then
				self:complete_step()
			end
		end
	end
	return action
end
