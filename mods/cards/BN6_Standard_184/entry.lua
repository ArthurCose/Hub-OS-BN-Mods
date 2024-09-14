local bn_assets = require("BattleNetwork.Assets")

local BARRIER_TEXTURE = bn_assets.load_texture("bn6_lifeaura.png")
local BARRIER_ANIMATION_PATH = bn_assets.fetch_animation_path("bn6_lifeaura.animation")
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
	local HP = 200

	local fading = false
	local isWind = false
	local remove_barrier = false

	local barrier = user:create_node()

	barrier:set_layer(3)
	barrier:set_texture(BARRIER_TEXTURE)

	barrier:set_never_flip(true)

	local barrier_animation = Animation.new(BARRIER_ANIMATION_PATH)
	barrier_animation:set_state("BARRIER_IDLE")
	barrier_animation:apply(barrier)

	barrier_animation:set_playback(Playback.Loop)

	local number = barrier:create_text_node(TextStyle.new("THICK"), "200")
	number:set_color(Color.new(0, 0, 0, 255))
	number:set_never_flip(true)
	number:set_offset(-10, 0)

	local number_shadow = number:create_text_node(TextStyle.new("THICK"), "70")
	number_shadow:set_offset(-1, -1)

	local barrier_defense_rule = DefenseRule.new(DefensePriority.Barrier, DefenseOrder.Always)
	barrier_defense_rule.defense_func = function(defense, attacker, defender)
		local attacker_hit_props = attacker:copy_hit_props()

		if attacker_hit_props.damage >= HP then
			HP = 0
		end

		defense:block_damage()

		if attacker_hit_props.element == Element.Wind then isWind = true end
	end

	local aura_animate_component = user:create_component(Lifetime.Battle)

	aura_animate_component.on_update_func = function(self)
		barrier_animation:apply(barrier)
		barrier_animation:update()
	end

	local aura_fade_countdown = 3000
	local aura_fade_component = user:create_component(Lifetime.ActiveBattle)
	aura_fade_component.on_update_func = function(self)
		if aura_fade_countdown <= 0 then
			remove_barrier = true
		else
			aura_fade_countdown = aura_fade_countdown - 1
		end
	end

	local aura_destroy_component = user:create_component(Lifetime.Battle)
	aura_destroy_component.on_update_func = function(self)
		if isWind and not fading then
			remove_barrier = true
		end

		if remove_barrier and not fading then
			remove_barrier = true
		end

		if HP <= 0 and not fading then
			remove_barrier = true
		end

		if barrier_defense_rule:replaced() then
			remove_barrier = true
		end

		if remove_barrier and not fading then
			fading = true
			user:remove_defense_rule(barrier_defense_rule)

			barrier_animation:set_state("BARRIER_FADE")
			barrier_animation:set_playback(Playback.Once)

			barrier_animation:on_complete(function()
				user:sprite():remove_node(barrier)
				aura_fade_component:eject()
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
