local old_make_frame_data = function(data) return data end
local function make_frame_data(frames)
	local updated_frames = {}
	for i, pair in ipairs(frames) do
		updated_frames[i] = { pair[1], math.floor(pair[2] * 60 + 0.5) }
	end
	return old_make_frame_data(updated_frames)
end

local panelgrab_chip = {}

local AUDIO = Resources.load_audio("sfx.ogg")
local FINISH_AUDIO = Resources.load_audio("finish_sfx.ogg")
local TEXTURE = Resources.load_texture("grab.png")
local FRAME1 = { 1, 1.3 }
local LONG_FRAME = make_frame_data({ FRAME1 })

function panelgrab_chip.card_init(actor)
	print("in create_card_action()!")
	local props = CardProperties.new()
	props.damage = 0
	props.short_name = "PanelGrab"
	props.time_freeze = true
	local action = Action.new(actor, "PLAYER_IDLE")
	action:override_animation_frames(LONG_FRAME)
	action:set_card_properties(props)
	action:set_lockout(ActionLockout.new_animation())
	action.on_execute_func = function(self, user)
		print("in custom card action execute_func()!")
		local tile = nil
		tile = user:get_tile()
		local dir = user:facing()
		local tile_to_grab = nil
		local count = 1
		local max = 6
		local tile_front = nil
		local check1 = false
		local check_front = nil

		for i = count, max, 1 do
			tile_front = tile:get_tile(dir, i)

			check_front = tile_front and user:team() ~= tile_front:team() and not tile_front:is_edge() and
					tile_front:team() ~= Team.Other and user:is_team(tile_front:get_tile(Direction.reverse(dir), 1):team())

			if check_front then
				tile_to_grab = tile_front
				break
			end
			print("tile at (" .. tile_front:x() .. "x, " .. tile_front:y() .. "y) has been skipped")
		end

		if tile_to_grab and not check1 then
			Resources.play_audio(AUDIO, AudioBehavior.Default)
			local fx = MakeTileSplash(user)
			user:field():spawn(fx, tile_to_grab)
			check1 = true
		end
		if tile_to_grab and check1 then
			Resources.play_audio(FINISH_AUDIO, AudioBehavior.Default)
		end
	end
	return action
end

function MakeTileSplash(user)
	local artifact = Artifact.new()
	artifact:sprite():set_texture(TEXTURE)
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
				self:current_tile():set_team(user:team(), user:facing())
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

return panelgrab_chip
