local bn_assets = require("BattleNetwork.Assets")

local BarrierLib = require("dev.GladeWoodsgrove.library.BarriersAndAuras")

local BARRIER_TEXTURE = bn_assets.load_texture("bubble.png")
local BARRIER_ANIMATION_PATH = bn_assets.fetch_animation_path("bubble.animation")
local BARRIER_UP_SOUND = bn_assets.load_audio("bblwrap_pop.ogg")
local DESTRUCTION_SOUND = bn_assets.load_audio("bubble_pop.ogg")

function card_init(user, props)
	local action = Action.new(user)
	local step = action:create_step()
	action:set_lockout(ActionLockout.new_sequence())

	-- Inputs are (owner, health)
	local barrier = BarrierLib.new_barrier(user, 1)

	-- Barrier/Aura data
	-- Texture & Animiation Path
	barrier:set_texture(BARRIER_TEXTURE)
	barrier:set_animation_path(BARRIER_ANIMATION_PATH)

	-- Animation State that loops while active
	barrier:set_active_state("WRAP")

	-- Animation State that plays once when disappearing.
	barrier:set_destroyed_state("WRAP_POP")

	-- Sound to play when barrier health drops to zero.
	barrier:set_destruction_sound(DESTRUCTION_SOUND)

	-- Mechnical data
	-- Set element that destroys the defense on hit.
	barrier:set_weakness_element({ Element.Elec, Element.Wind })

	barrier:set_regeneration_timer(283)
	barrier:set_regeneration_audio(BARRIER_UP_SOUND)

	local timer = 0
	step.on_update_func = function(self)
		timer = timer + 1
		if timer < 60 then return end
		self:complete_step()
	end

	local offset = { x = 0, y = -math.ceil(user:height() / 2) }

	action.on_execute_func = function(self)
		-- Adds the barrier to the user, completing the process.
		barrier:add_to_owner(offset)

		local elec_weakness = AuxProp.new()
			:require_hit_flags_absent(Hit.Drain)
			:require_hit_element(Element.Elec)
			:increase_hit_damage("DAMAGE")
			:with_callback(function()
				-- BubbleWrap shouldn't block damage on a wekaness hit (Elec)
				barrier:set_blocks_damage_on_weakness_hit(false)

				local alert_artifact = Alert.new()
				alert_artifact:sprite():set_never_flip(true)

				local movement_offset = user:movement_offset()
				alert_artifact:set_offset(movement_offset.x, movement_offset.y - user:height())

				Field.spawn(alert_artifact, user:current_tile())
				barrier:remove_barrier()
			end)
			:once()

		user:add_aux_prop(elec_weakness)

		-- Play the audio
		Resources.play_audio(BARRIER_UP_SOUND)
	end

	return action
end
