function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_IDLE")
	local number, time_display, current, trail, text, prop, offset_y

	action.on_execute_func = function()
		local timer = actor:create_component(Lifetime.ActiveBattle)

		local create_varsword_action = function(character)
			local card_properties = CardProperties.from_package("BattleNetwork3.Class01.Standard.039")
			local variable_action = Action.from_card(character, card_properties)
			return variable_action
		end

		local create_prop = function(character)
			prop = AuxProp.new()
				:require_action(ActionType.Card)
				:interrupt_action(function(next)
					return create_varsword_action(character)
				end)
				:once()

			character:add_aux_prop(prop)
		end

		local set_time_display = function(self)
			if time_display == nil then
				time_display = "5:00"
				number = tostring(4)
				return
			end

			if current % 60 == 0 then
				number = tostring(tonumber(number) - 1)
			end

			trail = tostring(current % 60)

			if current % 60 < 10 then
				trail = tostring(0) .. tostring(trail)
			end

			time_display = number .. ":" .. trail
		end

		local update_text = function(self)
			if text ~= nil then
				self:owner():sprite():remove_node(text)
			end

			text = actor:sprite():create_text_node(TextStyle.new("RESULT"), time_display)

			text:set_never_flip(true)

			text:set_offset(0, offset_y)
		end

		timer.on_init_func = function(self)
			set_time_display(self)
			current = 300
			offset_y = -math.min(70, (self:owner():height() / 2) + 24)
			update_text(self)
		end

		local end_advance = function(self)
			local owner = self:owner()
			if prop ~= nil then
				owner:remove_aux_prop(prop)
			end

			owner:sprite():remove_node(text)
			self:eject()
		end

		timer.on_update_func = function(self)
			current = current - 1

			if current <= 0 then
				end_advance(self)
				return
			end

			set_time_display(self)
			update_text(self)

			local owner = self:owner()

			if owner:has_actions() then return end
			if owner:field_card(1) ~= nil then
				create_prop(owner)
				return
			end

			if owner:input_has(Input.Pressed.Use) or owner:input_has(Input.Held.Use) then
				owner:queue_action(create_varsword_action(owner))
			end
		end
	end

	return action
end
