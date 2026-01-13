local bn_assets = require("BattleNetwork.Assets")
local spell_deleted = false

local ANIM_PATH = Resources.load_audio("RainyDay.animation")
local SHOT_TEXTURE = Resources.load_texture("Rain.png")

local AUDIO = Resources.load_audio("RainSound.ogg")
local CLOUD_SPAWNED = false
local FIRST_SHOT = false

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_IDLE")


	local start_columns = 0
	local end_columns = Field.width() - 1
	local x_increment = 1


	if (actor:facing() == Direction.Right) then
		start_columns, end_columns = end_columns, start_columns
		x_increment = -x_increment
	end

	local grab_finished = false
	local stall_timer = 0
	local tile_array = {}
	local tile_Index = 1
	local frame = { 1, 26 }
	local frame_times = { { 1, 26 } }
	for i = start_columns, end_columns, x_increment do
		for j = 0, Field.height() - 1, 1 do
			local tile = Field.tile_at(i, j)
			if tile:state() == TileState.Sea and tile:team() == actor:team() then
				table.insert(frame_times, frame)
			end
		end
	end

	action:override_animation_frames(frame_times)
	action:set_lockout(ActionLockout.new_async(300))


	action.on_execute_func = function(self, user)
		CLOUD_SPAWNED = false
		user:set_counterable(false)


		local shot = create_spell(user, props)
		local user_x = user:current_tile():x()
		local nearest = Field.find_nearest_characters(user, function(e)
			if e:team() == user:team() then
				return false
			end
			return true
		end)
		for i = start_columns, end_columns, x_increment do
			for j = 0, Field.height() - 1, 1 do
				local tile = Field.tile_at(i, j)

				if tile:state() == TileState.Sea and tile:team() == actor:team() then
					table.insert(tile_array, tile)
				end
			end
		end
		local tile = user:get_tile(user:facing(), 1)

		local rain_cloud = Artifact.new()
		local rain_cloud_sprite = rain_cloud:sprite()
		local anim = rain_cloud:animation()
		rain_cloud_sprite:set_texture("Cloud.png")

		rain_cloud:animation():load("Cloud.animation")
		rain_cloud:set_offset(0, -60)
		rain_cloud:animation():set_state("CLOUD_SPAWN")

		Field.spawn(rain_cloud, nearest[1]:current_tile())

		rain_cloud:animation():on_complete(function()
			anim:set_state("CLOUD_IDLE")
			anim:set_playback(Playback.Loop)
			Field.spawn(shot, nearest[1]:current_tile())
			CLOUD_SPAWNED = true
		end)

		local rain = action:create_step()
		rain.on_update_func = function()
			if CLOUD_SPAWNED then
				stall_timer = stall_timer + 1

				--print(grab_finished, spell_deleted, stall_timer)
				if grab_finished and stall_timer > 15 and anim:state() ~= "CLOUD_DESPAWN" then
					anim:set_state("CLOUD_DESPAWN")
					anim:set_playback(Playback.Once)

					anim:on_complete(function()
						rain_cloud:delete()
						rain_cloud:erase()
						self:end_action()
					end)
				end

				if stall_timer == 12 and grab_finished == false then
					if not grab_finished then
						if tile_Index <= #tile_array then
							tile_array[tile_Index]:set_state(TileState.Normal)

							local panelAbsorb = seaPanel_take(actor)
							Field.spawn(panelAbsorb, tile_array[tile_Index])
							local shot = create_spell(user, props)

							local tile = nearest[1]:current_tile()
							if tile then
								Field.spawn(shot, tile)
								Resources.play_audio(AUDIO)
							end
							stall_timer = 0
							tile_Index = tile_Index + 1
						else
							grab_finished = true
						end
					end
				end
			end
		end
	end



	return action
end

function create_spell(user, props)
	spell_deleted = false
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_hit_props(
		HitProps.from_card(
			props,
			user:context(),
			Drag.None
		)
	)
	spell:sharing_tile()

	local anim = spell:animation()
	spell:set_texture(SHOT_TEXTURE)




	spell:set_offset(0, -25)

	anim:load("Rain.animation")
	anim:set_state("DEFAULT")
	anim:set_playback(Playback.Loop)
	-- Allowed to attack

	-- Allowed to move


	spell.on_update_func = function(self)
		local tile = self:current_tile()

		self:attack_tile(tile)

		spell:animation():on_complete(function()
			spell:delete()
			spell:erase()
		end)
	end


	spell.on_delete_func = function(self)
		self:erase()
	end



	return spell
end

function seaPanel_take(user)
	local spell = Spell.new(user:team())
	spell:set_texture("SeaAbsorb.png")
	spell:set_facing(user:facing())

	spell.on_update_func = function(self)
		spell.on_update_func = nil
		local anim = spell:animation()
		anim:load("SeaAbsorb.animation")
		anim:set_state("GRAB")
		anim:set_playback(Playback.Once)
		spell:animation():on_complete(function()
			self:delete()
		end)
	end


	spell.on_delete_func = function(self)
		self:erase()
	end
	return spell
end
