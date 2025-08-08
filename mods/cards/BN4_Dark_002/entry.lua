local bn_assets = require("BattleNetwork.Assets")

---@type SwordLib
local SwordLib = require("dev.konstinople.library.sword")

local sword = SwordLib.new_sword()
sword:set_blade_texture(bn_assets.load_texture("sword_blades.png"))
sword:set_blade_animation_path(bn_assets.fetch_animation_path("sword_blades.animation"))
sword:set_blade_animation_state("DARK")

local SLASH_TEXTURE = bn_assets.load_texture("sword_slashes.png")
local SLASH_ANIM_PATH = bn_assets.fetch_animation_path("sword_slashes.animation")
local AUDIO = bn_assets.load_audio("lifesword.ogg")

local track_health = nil;

function card_mutate(user, card_index)
	local movement_component = user:create_component(Lifetime.ActiveBattle)
	movement_component._wait_timer = 7
	movement_component._count = 0

	movement_component.on_update_func = function(self)
		local owner = self:owner()
		self._count = self._count + 1
		if self._count % self._wait_timer == 0 and Living.from(owner) ~= nil then
			if owner:is_inactionable() or owner:is_immobile() or owner:is_moving() then return end
			local movement = Movement.new_teleport(owner:get_tile(owner:facing(), 1))

			owner:queue_movement(movement)
		end
	end

	if track_health == nil then
		track_health = user:create_component(Lifetime.ActiveBattle)
		track_health._stored_value = 0
		track_health._is_update_value = true
		track_health._field_list = Field.find_characters(function(ent)
			if Living.from(ent) == nil then return false end
			if ent:current_tile() == nil then return false end
			if user:is_team(ent:team()) then return false end
			return true
		end)

		track_health.on_update_func = function(self)
			local owner = self:owner()
			local card = owner:field_card(1)

			if card == nil then return end

			for _, tag in ipairs(card.tags) do
				if tag == "FOE_HEALTH_EQUALS_POWER" then
					for i = 1, #self._field_list, 1 do
						if self._field_list[i]:health() > self._stored_value then
							self._stored_value = self._field_list[i]:health()
						end
					end

					card.damage = math.min(500, self._stored_value)

					user:set_field_card(1, card)
				end
			end
		end
	end
end

---@param user Entity
function card_init(user, props)
	return sword:create_action(user, function()
		if track_health ~= nil then track_health:eject() end
		local spells = {}
		spawn_artifact(spells, user, "DARK")

		-- Attack in a two deep, three tall formation
		create_spell(spells, user, props, 1, -1)
		create_spell(spells, user, props, 1, 0)
		create_spell(spells, user, props, 1, 1)
		create_spell(spells, user, props, 2, -1)
		create_spell(spells, user, props, 2, 0)
		create_spell(spells, user, props, 2, 1)

		Resources.play_audio(AUDIO)
	end)
end

---@param user Entity
function create_spell(spells, user, props, x_offset, y_offset)
	local h_tile = user:get_tile(user:facing(), x_offset)
	if not h_tile then return end
	local tile = h_tile:get_tile(Direction.Down, y_offset)

	if not tile then
		return
	end

	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_hit_props(
		HitProps.from_card(
			props,
			user:context(),
			Drag.None
		)
	)

	spell.on_update_func = function(self)
		self:current_tile():attack_entities(self)
	end

	Field.spawn(spell, tile)

	spells[#spells + 1] = spell
end

---@param user Entity
function spawn_artifact(spells, user, state)
	local tile = user:get_tile(user:facing(), 1)
	if not tile then return end

	local fx = Artifact.new()
	fx:set_facing(user:facing())
	local anim = fx:animation()
	fx:set_texture(SLASH_TEXTURE)
	anim:load(SLASH_ANIM_PATH)
	anim:set_state(state)
	anim:on_complete(function()
		fx:erase()

		for _, spell in ipairs(spells) do
			spell:delete()
		end
	end)

	fx:set_elevation(10)
	Field.spawn(fx, tile)
end
