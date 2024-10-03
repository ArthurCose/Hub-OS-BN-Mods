local bn_assets = require("BattleNetwork.Assets")

local BARRIER_TEXTURE = bn_assets.load_texture("bn6_barriers.png")
local BARRIER_ANIMATION_PATH = bn_assets.fetch_animation_path("bn6_barriers.animation")
local BARRIER_UP_SOUND = bn_assets.load_audio("barrier.ogg")

function card_init(user, props)
	local PRESTEP = { 0, 3 }
	local END = { 0, 30 }
	local FRAMES = { PRESTEP, END }

	local action = Action.new(user, "CHARACTER_IDLE")
	action:set_lockout(ActionLockout.new_animation())
	action:override_animation_frames(FRAMES)

	action:add_anim_action(2, function()
		Resources.play_audio(BARRIER_UP_SOUND)
		create_barrier(user)
	end)

	return action
end

function create_barrier(user)
	local HP = 100

	local fading = false
	local isWind = false
	local remove_barrier = false

	local barrier = user:create_node()
	barrier:set_layer(3)
	barrier:set_texture(BARRIER_TEXTURE)

	local barrier_animation = Animation.new(BARRIER_ANIMATION_PATH)
	barrier_animation:set_state("BARR100")
	barrier_animation:apply(barrier)

	barrier_animation:set_playback(Playback.Loop)

	local barrier_defense_rule = DefenseRule.new(DefensePriority.Barrier, DefenseOrder.Always)
	barrier_defense_rule.defense_func = function(defense, attacker, defender)
		local attacker_hit_props = attacker:copy_hit_props()
		HP = HP - attacker_hit_props.damage

		defense:block_damage()

		if attacker_hit_props.element == Element.Wind then isWind = true end
	end

	local aura_animate_component = user:create_component(Lifetime.ActiveBattle)

	aura_animate_component.on_update_func = function(self)
		barrier_animation:apply(barrier)
		barrier_animation:update(barrier)
	end

	local aura_destroy_component = user:create_component(Lifetime.Battle)

	local destroy_aura = false

	barrier_defense_rule.on_replace_func = function()
		aura_animate_component:eject()
		aura_destroy_component:eject()
		user:remove_node(barrier)
	end

	aura_destroy_component.on_update_func = function(self)
		if (isWind or HP <= 0 or destroy_aura) then
			remove_barrier = true
		end

		if remove_barrier and not fading then
			fading = true
			user:remove_defense_rule(barrier_defense_rule)

			barrier_animation:set_playback(Playback.Once)

			barrier_animation:on_complete(function()
				user:sprite():remove_node(barrier)
				aura_animate_component:eject()
				aura_destroy_component:eject()
			end)

			if isWind then
				local initialX = barrier:offset().x
				local initialY = barrier:offset().y
				local facing_check = 1
				if user:facing() == Direction.Left then
					facing_check = -1
				end

				barrier_animation:on_frame(1, function()
					barrier:set_offset(facing_check * (-25 - initialX) * 0.5, -20 + initialY * 0.5)
				end)

				barrier_animation:on_frame(2, function()
					barrier:set_offset(facing_check * (-50 - initialX) * 0.5, -40 + initialY * 0.5)
				end)

				barrier_animation:on_frame(3, function()
					barrier:set_offset(facing_check * (-75 - initialX) * 0.5, -60 + initialY * 0.5)
				end)
			end
		end
	end

	user:add_defense_rule(barrier_defense_rule)
end
