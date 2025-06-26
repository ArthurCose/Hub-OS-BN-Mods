function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_IDLE")


	action.on_execute_func = function()
		local timer = actor:create_component(Lifetime.ActiveBattle)

		timer._create_varsword_action = function(character)
			local card_properties = CardProperties.from_package("BattleNetwork3.Class01.Standard.039")
			local variable_action = Action.from_card(character, card_properties)
			return variable_action
		end

		timer._create_prop = function(character)
			timer._prop = AuxProp.new()
				:require_action(ActionType.Card)
				:interrupt_action(function(next)
					-- local return_action = next:copy_card_properties()
					-- actor:insert_field_card(return_action, 1)
					return timer._create_varsword_action(character)
				end)
				:once()

			character:add_aux_prop(timer._prop)
		end

		timer._set_time_display = function(self)
			if self._time_display == nil then
				self._time_display = "5:00"
				self._number = tostring(4)
				return
			end

			if self._current % 60 == 0 then
				self._number = tostring(tonumber(self._number) - 1)
			end

			self._trail = tostring(self._current % 60)

			if self._current % 60 < 10 then
				self._trail = tostring(0) .. tostring(self._trail)
			end

			self._time_display = self._number .. ":" .. self._trail
		end

		timer._update_text = function(self)
			if self._text ~= nil then
				self:owner():sprite():remove_node(self._text)
			end

			self._text = actor:sprite():create_text_node(TextStyle.new("RESULT"), self._time_display)

			self._text:set_never_flip(true)

			self._text:set_offset(0, self._offset_y)
		end

		timer.on_init_func = function(self)
			self._set_time_display(self)
			self._current = 300
			self._offset_y = -math.min(70, (self:owner():height() / 2) + 24)
			self._update_text(self)
		end

		timer._end_advance = function(self)
			local owner = self:owner()
			if self._prop ~= nil then
				owner:remove_aux_prop(self._prop)
			end

			owner:sprite():remove_node(self._text)
			self:eject()
		end

		timer.on_update_func = function(self)
			self._current = self._current - 1

			if self._current <= 0 then
				self._end_advance(self)
				return
			end

			self._set_time_display(self)
			self._update_text(self)

			local owner = self:owner()

			if owner:has_actions() then return end
			if owner:field_card(1) ~= nil then
				self._create_prop(owner)
				return
			end

			if owner:input_has(Input.Pressed.Use) or owner:input_has(Input.Held.Use) then
				owner:queue_action(self._create_varsword_action(owner))
			end
		end
	end

	return action
end
