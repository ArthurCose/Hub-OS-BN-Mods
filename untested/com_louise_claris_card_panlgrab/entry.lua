nonce = function() end

local AUDIO = Resources.load_audio("sfx.ogg")
local FINISH_AUDIO = Resources.load_audio("finish_sfx.ogg")
local TEXTURE = Resources.load_texture("grab.png")
local FRAME1 = { 1, 1.3 }
local LONG_FRAME = { FRAME1 }



function card_init(actor, props)
	local action = Action.new(actor, "PLAYER_IDLE")
	action:override_animation_frames(LONG_FRAME)
	action:set_lockout(ActionLockout.new_animation())
	action.on_execute_func = function(self, user)
		local tile = nil
		tile = user:current_tile()
		local dir = user:facing()
		local tile_to_grab = nil
		local count = 1
		local max = 6
		local tile_front = nil
		local check1 = false
		local check_front = false
		local check_up = false
		local check_down = false

		for i = count, max, 1 do
			tile_front = tile:get_tile(dir, i)

			check_front = tile_front and user:team() ~= tile_front:team() and not tile_front:is_edge() and
				tile_front:team() ~= Team.Other and user:is_team(tile_front:get_tile(Direction.reverse(dir), 1):team())

			if check_front then
				tile_to_grab = tile_front
				break
			end
		end

		if tile_to_grab and not check1 then
			Resources.play_audio(AUDIO)
			local fx = MakeTileSplash(user)
			user:field():spawn(fx, tile_to_grab)
			check1 = true
		end
		if tile_to_grab and check1 then
			Resources.play_audio(FINISH_AUDIO)
		end
	end
	return action
end

function MakeTileSplash(user)
	local artifact = Artifact.new()
	artifact:sprite():set_texture(TEXTURE, true)
	local anim = artifact:animation()
	anim:load("areagrab.animation")
	anim:set_state("FALL")
	anim:apply(artifact:sprite())
	artifact:set_offset(0.0 * 0.5, -296.0 * 0.5)
	artifact:sprite():set_layer(-1)
	local doOnce = false
	artifact.on_update_func = function(self)
		if self:offset().y >= -16 then
			if not doOnce then
				self:set_offset(0.0 * 0.5, 0.0 * 0.5)
				self:animation():set_state("EXPAND")
				self:current_tile():set_team(user:team(), false)
				local hitbox = Hitbox.new(user:team())
				local props = HitProps.new(
					10,
					Hit.Impact,
					Element.None,
					user:context(),
					Drag.None
				)
				hitbox:set_hit_props(props)
				user:field():spawn(hitbox, self:current_tile())
				doOnce = true
			end
			self:animation():on_complete(
				function()
					self:delete()
				end
			)
		else
			self:set_offset(0.0 * 0.5, self:offset().y + 16.0 * 0.5)
		end
	end
	artifact.on_delete_func = function(self)
		self:erase()
	end
	return artifact
end
