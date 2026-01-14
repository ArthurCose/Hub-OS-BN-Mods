---@type BattleNetwork6.Libraries.ChipNavi
local ChipNaviLib = require("BattleNetwork6.Libraries.ChipNavi")
local bn_assets = require("BattleNetwork.Assets")

local NAVI_TEXTURE = bn_assets.load_texture("navi_blastman.png")
local NAVI_ANIM_PATH = bn_assets.fetch_animation_path("navi_blastman.animation")

local ATTACK_AUDIO = bn_assets.load_audio("firehit4.ogg")

local shadow = bn_assets.load_texture("navi_shadow.png")

---@param user Entity
---@param props CardProperties
function card_init(user, props)
	local action = Action.new(user)
	action:set_lockout(ActionLockout.new_sequence())
	action:create_step()

	local end_timer = 6 * (Field.width() + 2)
	local end_timer_started = false
	local previously_visible = user:sprite():visible()

	local function attempt_fireball(tile)
		if not tile then return end

		local fireball = Spell.new(user:team())
		fireball:set_facing(user:facing())
		fireball:set_hit_props(
			HitProps.from_card(props, user:context())
		)

		fireball:set_texture(NAVI_TEXTURE)

		fireball.can_move_to_func = function()
			return true
		end

		local spell_anim = fireball:animation()
		spell_anim:load(NAVI_ANIM_PATH)
		spell_anim:set_state("FLARE_BOMB_HORI")
		spell_anim:set_playback(Playback.Loop)

		fireball.on_update_func = function(self)
			if not self:is_sliding() then
				local next_tile = self:get_tile(self:facing(), 1)

				if not next_tile then
					self:erase()
					return
				end

				self:slide(next_tile, 6)
			end

			self:attack_tile()
		end

		fireball.on_collision_func = function(self, other)
			local other_sprite = other:sprite()
			local width = other_sprite:width()
			local height = other_sprite:height()

			local hit_effect = bn_assets.HitParticle.new("FIRE",
				(math.random(-50, 50) / 100) * width,
				(math.random(-50, 50) / 100) * height
			)

			fireball.can_move_to_func = function()
				return false
			end

			Field.spawn(hit_effect, self:current_tile())

			self:erase()
		end

		Field.spawn(fireball, tile)
	end

	---@type Entity
	local navi
	---@type Animation
	local navi_animation

	action.on_execute_func = function(self, user)
		previously_visible = user:sprite():visible()
		local direction = user:facing()
		local start_x = 0

		if direction == Direction.Left then
			start_x = Field.width() - 1
		end

		-- Setup the navi's sprite and animation.
		-- Done separately from the actual state and texture assignments for a reason.
		-- We need this to be accessible by other local functions down below.
		navi = Artifact.new(user:team())

		navi:set_shadow(shadow)

		local navi_sprite = navi:sprite()
		navi_animation = navi:animation()

		navi:set_facing(direction)
		navi_sprite:set_texture(NAVI_TEXTURE)
		navi_animation:load(NAVI_ANIM_PATH)

		local spawn_tile = user:current_tile()

		ChipNaviLib.swap_in(navi, user, function()
			navi_animation:set_state("CHARACTER_IDLE")

			navi_animation:on_complete(function()
				navi_animation:set_state("CHARACTER_FIRE_START")

				navi_animation:on_complete(function()
					navi_animation:set_state("CHARACTER_FIRE_HORI_LOOP")
					navi_animation:set_playback(Playback.Loop)

					navi_animation:on_frame(2, function()
						end_timer_started = true

						Resources.play_audio(ATTACK_AUDIO)

						for y = -1, 1, 1 do
							attempt_fireball(Field.tile_at(start_x, spawn_tile:y() + y))
						end
					end, true)
				end)
			end)
		end)

		Field.spawn(navi, spawn_tile)
	end

	action.on_update_func = function()
		if not end_timer_started then
			return
		end
		end_timer = end_timer - 1

		if end_timer == 0 then
			ChipNaviLib.swap_in(user, navi, function()
				action:end_action()
			end)
		end
	end

	action.on_action_end_func = function()
		if previously_visible then
			user:reveal()
		else
			user:hide()
		end

		if navi and not navi:deleted() then
			navi:erase()
		end
	end

	return action
end
