local bn_assets = require("BattleNetwork.Assets")

local BARRIER_TEXTURE = bn_assets.load_texture("bn6_lifeaura.png")
local BARRIER_ANIMATION_PATH = bn_assets.fetch_animation_path("bn6_lifeaura.animation")
local BARRIER_UP_SOUND = bn_assets.load_audio("lifeaura.ogg")

local BarrierLib = require("dev.GladeWoodsgrove.library.BarriersAndAuras")

function card_init(user, props)
	local action = Action.new(user)
	local step = action:create_step()
	action:set_lockout(ActionLockout.new_sequence())

	-- Inputs are (owner, health)
	local aura = BarrierLib.new_aura(user, 200)

	-- Barrier/Aura data
	-- Texture & Animiation Path
	aura:set_texture(BARRIER_TEXTURE)
	aura:set_animation_path(BARRIER_ANIMATION_PATH)

	-- Animation State that loops while active
	aura:set_active_state("BARRIER_IDLE")

	-- Automatically remove after this many frames
	aura:set_removal_timer(1500)

	-- Animation State that is used if the barrier removes on a timer
	aura:set_fade_state("BARRIER_FADE")

	-- Whether or not to draw health on the barrier
	aura:set_display_health(true)

	-- Mechnical data
	-- Set element that destroys the defense on hit.
	aura:set_weakness_element({ Element.Wind })

	local timer = 0
	step.on_update_func = function(self)
		timer = timer + 1
		if timer < 60 then return end
		self:complete_step()
	end

	action.on_execute_func = function(self)
		-- Adds the aura to the user, completing the process.
		aura:add_to_owner()

		-- Play the audio
		Resources.play_audio(BARRIER_UP_SOUND)
	end

	return action
end
