local FRAME1 = { 1, 6 }
local FRAMES = {FRAME1}

function card_init(user, props)
	local action = Action.new(user, "CHARACTER_IDLE")
	action:override_animation_frames(FRAMES)
	action:set_lockout(ActionLockout.new_animation())
	action.on_execute_func = function(self, user)
		self:on_anim_frame(1, function()
			local rng = math.random(1, 9)
			user:set_counterable(false)
			if rng == 1 then
				props.package_id = "BattleNetwork6.Class01.Standard.149"
				user:cancel_actions()
				user:queue_action(Action.from_card(user, props))
			elseif rng == 2 then
				props.package_id = "BattleNetwork6.Class01.Standard.150"
				user:cancel_actions()
				user:queue_action(Action.from_card(user, props))
			elseif rng == 3 then
				props.package_id = "BattleNetwork6.Class01.Standard.151"
				user:cancel_actions()
				user:queue_action(Action.from_card(user, props))
			elseif rng == 4 then
				props.package_id = "BattleNetwork6.Class01.Standard.152"
				user:cancel_actions()
				user:queue_action(Action.from_card(user, props))
			elseif rng == 5 then
				props.package_id = "dev.delta.card.xylos"
				user:cancel_actions()
				user:queue_action(Action.from_card(user, props))
			elseif rng == 6 then
				props.package_id = "MysticalSobble.card.mega.10.Outrage"
				user:cancel_actions()
				user:queue_action(Action.from_card(user, props))
			elseif rng == 7 then
				props.package_id = "BattleNetwork6.Class01.Standard.154.Guardian"
				user:cancel_actions()
				user:queue_action(Action.from_card(user, props))
			elseif rng == 8 then
				props.package_id = "BattleNetwork6.Class01.Standard.135.Fan"
				user:cancel_actions()
				user:queue_action(Action.from_card(user, props))
			else
				props.package_id = "BattleNetwork6.Class01.Standard.134.Wind"
				user:cancel_actions()
				user:queue_action(Action.from_card(user, props))
			end
		end)
	end

	return action
end