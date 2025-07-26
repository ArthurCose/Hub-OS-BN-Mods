local bn_assets = require("BattleNetwork.Assets")

local buster_texture = bn_assets.load_texture("zap_buster.png")
local buster_anim_path = bn_assets.fetch_animation_path("zap_buster.animation")

local buster_audio = bn_assets.load_audio("physical_projectile.ogg")

local ring_texture = bn_assets.load_texture("zap_ring.png")
local ring_anim_path = bn_assets.fetch_animation_path("zap_ring.animation")

function card_init(player, props)
	local action = Action.new(player, "CHARACTER_SHOOT")

	action:override_animation_frames(
		{
			{ 1, 2 },
			{ 2, 3 },
			{ 3, 2 },
			{ 3, 8 }
		}
	)

	action:set_lockout(ActionLockout.new_animation())

	action.on_execute_func = function(self, user)
		local facing = user:facing()

		self:add_anim_action(1, function()
			local buster = self:create_attachment("BUSTER")
			local buster_sprite = buster:sprite()
			buster_sprite:set_texture(buster_texture)
			buster_sprite:set_layer(-1)
			buster_sprite:use_root_shader()

			local buster_anim = buster:animation()
			buster_anim:load(buster_anim_path)
			buster_anim:set_state("SPAWN")
		end)

		self:add_anim_action(3, function()
			local spell = Spell.new(user:team())

			spell:set_facing(facing)

			spell:set_texture(ring_texture)

			spell:set_elevation(25)

			local spell_anim = spell:animation()
			spell_anim:load(ring_anim_path)
			spell_anim:set_state("DEFAULT")
			spell_anim:set_playback(Playback.Loop)

			spell._slide_started = false

			local direction = facing
			spell:set_hit_props(
				HitProps.from_card(
					props,
					user:context(),
					Drag.None
				)
			)

			spell.on_spawn_func = function()
				Resources.play_audio(buster_audio)
			end

			spell.on_update_func = function(self)
				self:attack_tile()

				local tile = self:current_tile()

				if not self:is_sliding() then
					if tile:is_edge() and self._slide_started then
						self:erase()
					end

					local dest = self:get_tile(direction, 1)
					local ref = self

					self:slide(dest, 4, function() ref._slide_started = true end)
				end
			end

			spell.on_collision_func = function(self, other)
				self:erase()
			end

			spell.can_move_to_func = function(tile)
				return true
			end

			user:field():spawn(spell, user:get_tile(facing, 1))
		end)
	end
	return action
end
