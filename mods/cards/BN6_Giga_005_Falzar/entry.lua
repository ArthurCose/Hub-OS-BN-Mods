local bn_assets = require("BattleNetwork.Assets")

local TEXTURE = bn_assets.load_texture("bugrise.png")
local ANIM_PATH = bn_assets.fetch_animation_path("bugrise.animation")

local AUDIO = bn_assets.load_audio("bug_power.ogg")

function card_init(user, props)
	local action = Action.new(user)

	-- Create a step and set a sequence lockout to keep the action going until we complete that step.
	local step = action:create_step()

	action:set_lockout(ActionLockout.new_sequence())

	action.on_execute_func = function()
		-- Create the visual
		local bug_rise = Artifact.new()
		local bug_rise_sprite = bug_rise:sprite()
		local bug_rise_animation = bug_rise:animation()

		bug_rise_sprite:set_texture(TEXTURE)

		bug_rise_animation:load(ANIM_PATH)

		bug_rise_animation:set_state("DEFAULT")

		-- Play audio associated with the visual
		bug_rise_animation:on_frame(1, function()
			Resources.play_audio(AUDIO)
		end)

		-- Complete the step to allow the action to end now that the animation is done.
		bug_rise_animation:on_complete(function()
			step:complete_step()
		end)

		user:boost_augment("BattleNetwork6.ArmChange.BugDeathThunder", 1)

		-- Spawn the visual artifact
		Field.spawn(bug_rise, user:current_tile())
	end

	return action
end
