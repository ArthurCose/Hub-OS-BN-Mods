local DAMAGE = 0
local DAMAGE2 = 10

local AREASTEAL_AUDIO_START = Resources.load_audio("exe6-areasteal-start.ogg")
local AREASTEAL_AUDIO_FINISH = Resources.load_audio("exe6-areasteal-finish.ogg")
local AREASTEAL_TEXTURE = Resources.load_texture("areasteal.png")
local AREASTEAL_ANIMPATH = "areasteal.animation"

local FRAME1 = { 1, 1.3 }
local LONG_FRAME = { FRAME1 }

local panelsteal = {
	codes = { "*" },
	short_name = "PanlStel",
	damage = DAMAGE,
	time_freeze = true,
	element = Element.None,
	description = "Steals 1 enemy square!",
	long_description = "Repaint 1 panel in front of the enemy area to your area",
	can_boost = false,
	card_class = CardClass.Standard,
	memory = 6,
	limit = 5
}



function card_init(actor, props)
	local action = Action.new(actor, "PLAYER_IDLE")
	action:override_animation_frames(LONG_FRAME)
	action:set_lockout(ActionLockout.new_animation())
	action.on_execute_func = function(self, user)
		local field = user:field()
		local team = user:team()
		local direction = user:facing()

		local tile = user:current_tile()
		local tile_array = {}
		local count = 1
		local max = 6
		local tile_front = nil
		local check1 = false
		local check_front = false

		for i = count, max, 1 do
			tile_front = tile:get_tile(direction, i)

			check_front = tile_front and user:team() ~= tile_front:team() and not tile_front:is_edge() and
				tile_front:team() ~= Team.Other and
				user:is_team(tile_front:get_tile(Direction.reverse(direction), 1):team())

			if check_front then
				table.insert(tile_array, tile_front)
				break
			end
		end

		if #tile_array > 0 and not check1 then
			Resources.play_audio(AREASTEAL_AUDIO_START)
			for i = 1, #tile_array, 1 do
				local fx = MakeTileSplash(user)
				user:field():spawn(fx, tile_array[i])
			end
			check1 = true
		end
		--[[if #tile_array > 0 and check1 then
			Engine.play_audio(FINISH_AUDIO)
		end]]
	end
	return action
end

function MakeTileSplash(user)
	local artifact = Artifact.new()
	artifact:sprite():set_texture(AREASTEAL_TEXTURE, true)
	local anim = artifact:animation()
	anim:load(AREASTEAL_ANIMPATH)
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
				self:animation():on_frame(1, function()
					Resources.play_audio(AREASTEAL_AUDIO_FINISH)
				end)
				local hitbox = Hitbox.new(user:team())
				local props = HitProps.new(
					DAMAGE2,
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
