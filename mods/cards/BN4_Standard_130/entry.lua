local bn_assets = require("BattleNetwork.Assets")

local wind_puff_texture = bn_assets.load_texture("wind_puff.png")
local wind_puff_animation_path = bn_assets.fetch_animation_path("wind_puff.animation")
local wind_puff_audio = bn_assets.load_audio("wind_burst.ogg")

function card_init(actor, props)
	local action = Action.new(actor, actor:animation():state())

	action:override_animation_frames({ { 1, 180 } })

	action.on_execute_func = function()
		Resources.play_audio(wind_puff_audio)
	end

	local wind_timer = 0
	local wind_tile = Field.tile_at(0, 0)

	action.on_update_func = function(self)
		wind_timer = wind_timer + 1

		if wind_timer >= 40 then
			for x = 1, Field.width(), 1 do
				for y = 1, Field.height(), 1 do
					local spell_tile = Field.tile_at(x, y)
					if spell_tile == nil then goto continue end

					local spell = Spell.new(actor:team())
					spell:set_hit_props(
						HitProps.new(
							0,
							Hit.None,
							Element.Wind,
							actor:context(),
							Drag.None
						)
					)

					spell.on_update_func = function(self)
						self:attack_tile()
						self:erase()
					end

					Field.spawn(spell, spell_tile)

					::continue::
				end
			end
		end

		if wind_timer >= 120 then
			return
		end

		if wind_timer % 8 == 0 then
			local wind = Spell.new(Team.Other)
			wind:set_texture(wind_puff_texture)

			wind:sprite():set_layer(-4)

			local wind_anim = wind:animation()
			wind_anim:load(wind_puff_animation_path)
			wind_anim:set_state("DEFAULT")

			local goal_width = wind_tile:width() * 7
			local goal_height = wind_tile:height() * 4

			wind._goal = { x = goal_width, y = goal_height }
			wind._current_tile_pos = { x = 0, y = 0 }
			wind._erase_timer = 30
			wind._offset_y_list = { 7.5, 7.5, 0, 7.5, 7.5, 7.5, 7.5, 7.5 }
			wind._offset_y_list[0] = 7.5
			wind.on_update_func = function(self)
				local offset = self:offset()

				self:set_offset(offset.x + 24, offset.y + self._offset_y_list[self._current_tile_pos.x])

				if self._current_tile_pos.x >= 7 then
					self._erase_timer = self._erase_timer - 1
					if self._erase_timer > 0 then return end

					self:erase()
					return
				end

				if math.floor(offset.x / 40) > self._current_tile_pos.x then
					self._current_tile_pos.x = math.min(Field.width(), self._current_tile_pos.x + 1)
				end

				if math.floor(offset.y / 30) > self._current_tile_pos.y then
					self._current_tile_pos.y = math.min(4, self._current_tile_pos.y + 1)
				end
			end

			Field.spawn(wind, wind_tile)
		end
	end

	return action
end
