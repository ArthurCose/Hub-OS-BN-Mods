local FRAME1 = { 1, 6 }
local FRAMES = {FRAME1}

function card_init(user, props)
	local action = Action.new(user, "CHARACTER_IDLE")
	action:override_animation_frames(FRAMES)
	action:set_lockout(ActionLockout.new_animation())
	action.on_execute_func = function(self, user)
		self:on_anim_frame(1, function()
			local rng = math.random(1, 10)
			user:set_counterable(false)
			if rng == 1 then
				local obj = CardProperties.from_package("BattleNetwork6.Class01.Standard.149")
				obj.prevent_time_freeze_counter = true
				obj.skip_time_freeze_intro = true
				user:queue_action(Action.from_card(user, obj))
			elseif rng == 2 then
				local obj = CardProperties.from_package("BattleNetwork6.Class01.Standard.150")
				obj.prevent_time_freeze_counter = true
				obj.skip_time_freeze_intro = true
				user:queue_action(Action.from_card(user, obj))
			elseif rng == 3 then
				local obj = CardProperties.from_package("BattleNetwork6.Class01.Standard.151")
				obj.prevent_time_freeze_counter = true
				obj.skip_time_freeze_intro = true
				user:queue_action(Action.from_card(user, obj))
			elseif rng == 4 then
				local obj = CardProperties.from_package("BattleNetwork6.Class01.Standard.152")
				obj.prevent_time_freeze_counter = true
				obj.skip_time_freeze_intro = true
				user:queue_action(Action.from_card(user, obj))
			elseif rng == 5 then
				local obj = CardProperties.from_package("dev.delta.card.xylos")
				obj.prevent_time_freeze_counter = true
				obj.skip_time_freeze_intro = true
				user:queue_action(Action.from_card(user, obj))
			elseif rng == 6 then
				local obj = CardProperties.from_package("BattleChipChallenge.Ring.Card.050")
				obj.prevent_time_freeze_counter = true
				obj.skip_time_freeze_intro = true
				user:queue_action(Action.from_card(user, obj))
			elseif rng == 7 then
				local obj = CardProperties.from_package("MysticalSobble.card.mega.10.Outrage")
				obj.prevent_time_freeze_counter = true
				obj.skip_time_freeze_intro = true
				user:queue_action(Action.from_card(user, obj))
			elseif rng == 8 then
				local obj = CardProperties.from_package("BattleNetwork6.Class01.Standard.154.Guardian")
				obj.prevent_time_freeze_counter = true
				obj.skip_time_freeze_intro = true
				user:queue_action(Action.from_card(user, obj))
			elseif rng == 9 then
				local obj = CardProperties.from_package("BattleNetwork6.Class01.Standard.134.Wind")
				obj.prevent_time_freeze_counter = true
				obj.skip_time_freeze_intro = true
				user:queue_action(Action.from_card(user, obj))
			else
				local obj = CardProperties.from_package("BattleNetwork6.Class01.Standard.135.Fan")
				obj.prevent_time_freeze_counter = true
				obj.skip_time_freeze_intro = true
				user:queue_action(Action.from_card(user, obj))
			end
		end)
	end

	return action
end