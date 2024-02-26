nonce = function() end

local DAMAGE = 240
local SLASH_TEXTURE = Resources.load_texture("spell_sword_slashes.png")
local BLADE_TEXTURE = Resources.load_texture("spell_sword_blades.png")
local AUDIO = Resources.load_audio("sfx.ogg")



function card_init(actor, props)
	local action = Action.new(actor, "PLAYER_IDLE")
	action:set_lockout(ActionLockout.new_sequence())
	action.on_execute_func = function(self, user)
		local step1 = self:create_step()
		local cooldown = 10
		local slashed = false
		local tile_array = {}
		local field = user:field()
		local ref = self
		local do_once = true
		for i = 0, 6, 1 do
			for j = 0, 6, 1 do
				local tile = field:tile_at(i, j)
				if tile and not tile:is_edge() and user:is_team(tile:team()) then
					table.insert(tile_array, tile)
				end
			end
		end
		local query = function(character)
			return character:current_tile():team() == user:team()
		end
		step1.on_update_func = function(self)
			if cooldown > 0 then
				if user:input_has(Input.Held.Use) then
					for k = 1, #tile_array, 1 do
						local triggered = #tile_array[k]:find_characters(query) > 0
						if triggered and not tile_array[k]:contains_entity(user) then
							if do_once then
								local action2 = Action.new(user, "PLAYER_SWORD")
								action2:set_lockout(ActionLockout.new_animation())
								slashed = true
								action2.on_execute_func = function(self, user2)
								end
								action2:add_anim_action(2, function()
									local hilt = action2:create_attachment("HILT")
									local hilt_sprite = hilt:sprite()
									hilt_sprite:set_texture(actor:texture())
									hilt_sprite:set_layer(-2)
									hilt_sprite:use_root_shader(true)

									local hilt_anim = hilt:animation()
									hilt_anim:copy_from(actor:animation())
									hilt_anim:set_state("HILT")

									local blade = hilt:create_attachment("ENDPOINT")
									local blade_sprite = blade:sprite()
									blade_sprite:set_texture(BLADE_TEXTURE)
									blade_sprite:set_layer(-1)

									local blade_anim = blade:animation()
									blade_anim:load("spell_sword_blades.animation")
									blade_anim:set_state("DEFAULT")
								end)
								action2:add_anim_action(2, function()
									local sword = create_slash(user, props)
									local tile = user:get_tile(user:facing(), 1)
									local fx = Artifact.new()
									fx:set_facing(sword:facing())
									local anim = fx:animation()
									fx:set_texture(SLASH_TEXTURE, true)
									anim:load("spell_sword_slashes.animation")
									anim:set_state("WIDE")
									anim:on_complete(function()
										fx:erase()
										sword:erase()
									end)
									field:spawn(fx, tile_array[k])
									field:spawn(sword, tile_array[k])
									self:complete_step()
								end)
								user:queue_action(action2)
								do_once = false
							end
						end
						if slashed then
							self:complete_step()
							break
						end
					end
				elseif not user:input_has(Input.Held.Use) then
					self:complete_step()
				end
				cooldown = cooldown - 1
				if slashed then
					self:complete_step()
				end
			else
				self:complete_step()
			end
		end
	end
	return action
end

function create_slash(user, props)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_tile_highlight(Highlight.Flash)
	spell:set_hit_props(
		HitProps.new(
			props.damage,
			Hit.Impact | Hit.Flinch | Hit.Flash,
			props.element,
			user:context(),
			Drag.None
		)
	)
	spell.on_update_func = function(self)
		self:current_tile():attack_entities(self)
	end

	spell.can_move_to_func = function(tile)
		return true
	end

	Resources.play_audio(AUDIO)

	return spell
end
