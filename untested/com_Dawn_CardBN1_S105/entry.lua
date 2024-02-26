local TEXTURE = Resources.load_texture("RockCube.png")
local sfx = Resources.load_audio("sfx.ogg")

function card_init(actor, props)
	local action = Action.new(actor, "PLAYER_IDLE")
	action:set_lockout(ActionLockout.new_sequence())
	action.on_execute_func = function(self, user)
		local step1 = self:create_step()
		local cube = Obstacle.new(Team.Other)
		local do_once = true
		step1.on_update_func = function(self)
			if do_once then
				do_once = false
				Resources.play_audio(sfx)
				cube:set_facing(user:facing())
				cube:set_texture(TEXTURE, true)
				local anim = cube:animation()
				anim:load("RockCube.animation")
				anim:set_state("SPAWN")
				anim:apply(cube:sprite())
				anim:on_complete(function()
					local tile = cube:current_tile()
					if tile:is_walkable() then
						anim:set_state("DEFAULT")
						anim:apply(cube:sprite())
						anim:set_playback(Playback.Loop)
					else
						cube:delete()
					end
				end)
				cube:set_health(60)

				-- deletion process var
				local delete_self = nil
				local spawned_hitbox = false
				local countdown = 6000
				-- slide tracker
				local continue_slide = false
				local prev_tile = {}
				local cube_speed = 4

				-- define cube collision hitprops
				local props = HitProps.new(
					200,
					Hit.Impact | Hit.Flinch | Hit.Flash | Hit.PierceGuard,
					Element.Aqua,
					user:context(),
					Drag.None
				)


				-- upon tangible collision
				cube.on_collision_func = function(self)
					-- define the hitbox with its props every frame
					local hitbox = Hitbox.new(cube:team())
					hitbox:set_hit_props(props)

					if not spawned_hitbox then
						cube:field():spawn(hitbox, cube:current_tile())
						spawned_hitbox = true
					end
					cube:delete()
				end
				-- upon passing the defense check
				cube.on_attack_func = function(self)
				end

				cube.can_move_to_func = function(tile)
					if tile then
						-- get a list of every obstacle with Team.Other on the field
						local field = cube:field()
						local cube_team = cube:team()
						local Other_obstacles = function(obstacle)
							return obstacle:team() == cube_team
						end
						local obstacles_here = field:find_obstacles(Other_obstacles)
						local donotmove = false
						-- look through the list of obstacles and read their tile position, check if we're trying to move to their tile.
						for ii = 1, #obstacles_here do
							if tile == obstacles_here[ii]:current_tile() then
								donotmove = true
							end
						end

						if tile:is_edge() or donotmove or not tile:is_walkable() then
							return false
						end
					end
					return true
				end
				cube.on_update_func = function(self)
					local tile = cube:current_tile()
					if not tile then
						cube:delete()
					end
					if tile:is_edge() then
						cube:delete()
					end
					if not delete_self then
						tile:attack_entities(cube)
					end
					local direction = self:facing()
					if self:is_sliding() then
						table.insert(prev_tile, 1, tile)
						prev_tile[cube_speed + 1] = nil
						local target_tile = tile:get_tile(direction, 1)
						if self:can_move_to(target_tile) then
							continue_slide = true
						else
							continue_slide = false
						end
					else
						-- become aware of which direction you just moved in, turn to face that direction
						if prev_tile[cube_speed] then
							if prev_tile[cube_speed]:get_tile(direction, 1):x() ~= tile:x() then
								direction = self:facing_away()
								self:set_facing(direction)
							end
						end
					end
					if not self:is_sliding() and continue_slide then
						self:slide(self:get_tile(direction, 1), (cube_speed), (0), function() end)
					end
					if self and not self:hittable() then
						cube:delete()
					end
					if countdown > 0 then countdown = countdown - 1 else cube:delete() end

					-- deletion handler in main loop, starts running once something in here has requested deletion
					if delete_self then
						if type(delete_self) ~= "number" then
							delete_self = 2
						end
						if delete_self > 0 then
							delete_self = delete_self - 1
						elseif delete_self == 0 then
							delete_self = -1
							self:erase()
						end
					end
				end
				cube.on_delete_func = function(self)
					if type(delete_self) ~= "number" then
						delete_self = true
					end
					self:erase()
				end
				local desired_tile = user:get_tile(user:facing(), 1)
				if not desired_tile:is_edge() then
					user:field():spawn(cube, user:get_tile(user:facing(), 1))
				end
				self:complete_step()
			end
		end
	end
	return action
end
