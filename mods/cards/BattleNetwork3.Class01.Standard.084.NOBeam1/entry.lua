local bn_assets = require("BattleNetwork.Assets")

local battle_helpers = require("Battle.Helpers")

local AUDIO = bn_assets.load_audio("laser.ogg")

local NOBeam = Resources.load_texture("beam.png")
local anim_path = "beam.animation"

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_HIT")

	action:override_animation_frames({ { 1, 40 } })

	action:set_lockout(ActionLockout.new_animation())

	action.on_execute_func = function(self, user)
		local behind_tile = user:get_tile(user:facing_away(), 1)

		-- Need a tile. Shouldn't be a problem, but just in case.
		if not behind_tile then return end

		-- Need an obstacle behind
		if #behind_tile:find_obstacles(function() return true end) == 0 then
			return
		end

		local spell = Spell.new(user:team())

		spell:set_hit_props(HitProps.from_card(props, user:context()))

		spell:set_texture(NOBeam)

		local spell_anim = spell:animation()

		spell:set_facing(user:facing())

		spell_anim:load(anim_path)

		spell_anim:set_state("DEFAULT")
		spell_anim:set_playback(Playback.Loop)

		spell.can_move_to = function()
			return true
		end

		spell.on_spawn_func = function()
			Resources.play_audio(AUDIO)
		end

		local function drop_trace_fx(target_artifact, lifetime_ms)
			--drop an afterimage artifact mimicking the appearance of an existing spell/artifact/character and fade it out over it's lifetime_ms
			local fx = Artifact.new()
			local anim = target_artifact:animation()
			local offset = target_artifact:offset()
			local texture = target_artifact:texture()
			local elevation = target_artifact:elevation()
			fx:set_facing(target_artifact:facing())
			fx:set_texture(texture)
			fx:animation():copy_from(anim)
			fx:animation():set_state(anim:state())
			fx:set_offset(offset.x * 0.5, offset.y * 0.5)
			fx:set_elevation(elevation)
			fx:animation():apply(fx:sprite())
			local remaining_ms = lifetime_ms
			fx._slide_wait = 5
			fx.on_update_func = function(self)
				if self._slide_wait > 0 then
					self._slide_wait = self._slide_wait - 1
				else
					if not self:is_sliding() then
						local tile = self:current_tile()
						if not tile or tile:is_edge() then
							self:erase()
							return
						end

						local dest = tile:get_tile(self:facing(), 1)

						if not dest then
							self:erase()
							return
						end

						self:slide(dest, 8, function() end)
					end
				end
				remaining_ms = math.max(0, remaining_ms - math.floor((1 / 60) * 1000))
				local alpha = math.floor((remaining_ms / lifetime_ms) * 255)
				self:set_color(Color.new(0, 192, 192, alpha))

				if remaining_ms == 0 then
					self:erase()
				end
			end

			local tile = target_artifact:current_tile()
			Field.spawn(fx, tile:x(), tile:y())
			return fx
		end

		local main_color = Color.new(0, 192, 192, 255)

		spell._ghost_timer = 0

		spell.on_update_func = function(self)
			self._ghost_timer = self._ghost_timer + 1
			if self._ghost_timer % 4 == 0 then
				drop_trace_fx(self, 40)
			end
			self:set_color(main_color)

			drop_trace_fx(self, 420)

			self:attack_tile()
			if not self:is_sliding() then
				local tile = self:current_tile()
				if not tile or tile:is_edge() then
					self:erase()
					return
				end

				local dest = tile:get_tile(self:facing(), 1)

				if not dest then
					self:erase()
					return
				end

				self:slide(dest, 8, function() end)
			end
		end

		Field.spawn(spell, user:current_tile())
	end

	return action
end
