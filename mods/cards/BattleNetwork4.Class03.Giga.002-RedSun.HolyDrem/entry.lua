local bn_assets = require("BattleNetwork.Assets")
local spell_deleted = false


local SHOT_TEXTURE = Resources.load_texture("HolyDream_attack.png")

local AUDIO = Resources.load_audio("ClipClopClipClopHorseyTime.ogg")

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_SHOOT")


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

			if tile:state() == TileState.Holy then
				table.insert(tile_array, tile)
				table.insert(frame_times, frame)
			end
		end
	end

	action:override_animation_frames(frame_times)
	action:set_lockout(ActionLockout.new_async(300))


	action.on_execute_func = function(self, user)
		local buster = self:create_attachment("BUSTER")
		buster:sprite():set_texture(user:texture("battle.png"))
		buster:sprite():set_layer(-1)

		local buster_anim = buster:animation()
		buster_anim:copy_from(user:animation("battle.animation"))


		buster_anim:set_state("BUSTER", frame_times)


		user:set_counterable(false)

		local shot = create_spell(user, props)

		local tile = user:get_tile(user:facing(), 1)



		if tile then
			Field.spawn(shot, tile)
		end

		local shoot_spells = action:create_step()
		shoot_spells.on_update_func = function()
			stall_timer = stall_timer + 1
			if grab_finished and spell_deleted and stall_timer > 15 then
				self:end_action()
			end

			if stall_timer == 12 and grab_finished == false then
				if not grab_finished then
					if tile_Index <= #tile_array then
						tile_array[tile_Index]:set_state(TileState.Normal)

						local panelAbsorb = holyPanel_take(actor)
						Field.spawn(panelAbsorb, tile_array[tile_Index])
						local shot = create_spell(user, props)

						local tile = user:get_tile(user:facing(), 1)
						if tile then
							Field.spawn(shot, tile)
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

	local attacking = false
	spell:set_tile_highlight(Highlight.Flash)

	local anim = spell:animation()
	spell:set_texture(SHOT_TEXTURE)

	spell._can_move_yet = false

	local buster_point = user:animation():get_point("BUSTER")
	local origin = user:sprite():origin()
	local fire_x = buster_point.x - origin.x + (21 - user:current_tile():width())
	local fire_y = buster_point.y - origin.y

	spell:set_offset(fire_x, fire_y)

	anim:load("HolyDream_attack.animation")
	anim:set_state("DEFAULT")
	anim:set_playback(Playback.Loop)
	-- Allowed to attack
	attacking = true

	-- Allowed to move
	spell._can_move_yet = true


	spell.on_update_func = function(self)
		if not attacking then return end

		local tile = self:current_tile()

		self:attack_tile(tile)

		if self:is_sliding() == false and spell._can_move_yet == true then
			if tile:is_edge() then self:delete() end

			local dest = self:get_tile(spell:facing(), 1)

			self:slide(dest, 5)
		end
	end

	spell.on_collision_func = function(self, other)
		self:delete()
	end

	spell.on_delete_func = function(self)
		self:erase()
		spell_deleted = true
	end

	spell.can_move_to_func = function(tile)
		return spell._can_move_yet
	end

	spell.on_spawn_func = function()
		Resources.play_audio(AUDIO)
	end

	return spell
end

function holyPanel_take(user)
	local spell = Spell.new(user:team())
	spell:set_texture("HolyAbsorb.png")
	spell:set_facing(user:facing())

	spell.on_update_func = function(self)
		spell.on_update_func = nil
		local anim = spell:animation()
		anim:load("HolyAbsorb.animation")
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
