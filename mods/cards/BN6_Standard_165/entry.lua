local bn_helpers = require("dev.GladeWoodsgrove.BattleNetworkHelpers")

local AUDIO = bn_helpers.load_audio("panelgrab1.ogg")
local FINISH_AUDIO = bn_helpers.load_audio("panelgrab2.ogg")

local TEXTURE = bn_helpers.load_texture("PanelSteal.png")
local STEAL_ANIM = bn_helpers.fetch_animation_path("PanelSteal.animation")

local FRAME1 = { 1, 78 }
local LONG_FRAME = { FRAME1 }

function card_init(actor, props)
	local action = Action.new(actor, "PLAYER_IDLE")

	action:override_animation_frames(LONG_FRAME)

	action:set_lockout(ActionLockout.new_animation())

	action.on_execute_func = function(self, user)
		local tile = nil
		if user:team() == Team.Red then
			if user:facing() == Direction.Right then
				tile = user:field():tile_at(1, 2)
			else
				tile = user:field():tile_at(6, 2)
			end
		else
			if user:facing() == Direction.Left then
				tile = user:field():tile_at(6, 2)
			else
				tile = user:field():tile_at(1, 2)
			end
		end
		local dir = user:facing()
		local tile_array = {}
		local count = 1
		local max = 6
		local tile_front = nil
		local tile_up = nil
		local tile_down = nil
		local check1 = false
		local check_front = nil
		local check_up = nil
		local check_down = nil

		for i = count, max, 1 do
			tile_front = tile:get_tile(dir, i)
			tile_up = tile_front:get_tile(Direction.Up, 1)
			tile_down = tile_front:get_tile(Direction.Down, 1)

			check_front = tile_front and user:team() ~= tile_front:team() and not tile_front:is_edge() and
					tile_front:team() ~= Team.Other and user:is_team(tile_front:get_tile(Direction.reverse(dir), 1):team())
			check_up = tile_up and user:team() ~= tile_up:team() and not tile_up:is_edge() and
					tile_up:team() ~= Team.Other and user:is_team(tile_up:get_tile(Direction.reverse(dir), 1):team())
			check_down = tile_down and user:team() ~= tile_down:team() and not tile_down:is_edge() and
					tile_down:team() ~= Team.Other and user:is_team(tile_down:get_tile(Direction.reverse(dir), 1):team())

			if check_front or check_up or check_down then
				table.insert(tile_array, tile_front)
				table.insert(tile_array, tile_up)
				table.insert(tile_array, tile_down)
				break
			end
		end

		if #tile_array > 0 and not check1 then
			Resources.play_audio(AUDIO)
			for i = 1, #tile_array, 1 do
				local fx = MakeTileSplash(user)
				user:field():spawn(fx, tile_array[i])
			end
			check1 = true
		end
		if #tile_array > 0 and check1 then
			Resources.play_audio(FINISH_AUDIO)
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
