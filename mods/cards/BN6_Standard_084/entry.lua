local bn_assets = require("BattleNetwork.Assets")

---@type SwordLib
local SwordLib = require("dev.konstinople.library.sword")

local sword = SwordLib.new_sword()
sword:set_default_blade_texture(bn_assets.load_texture("sword_blades.png"))
sword:set_default_blade_animation_path(bn_assets.fetch_animation_path("sword_blades.animation"))

local SLASH_TEXTURE = bn_assets.load_texture("sword_slashes.png")
local SLASH_ANIM_PATH = bn_assets.fetch_animation_path("sword_slashes.animation")
local AUDIO = bn_assets.load_audio("sword.ogg")

local track_health = nil;

function card_mutate(user, card_index)
	if track_health == nil then
		track_health = user:create_component(Lifetime.ActiveBattle)
		track_health._stored_value = 0
		track_health._is_update_value = true
		track_health.on_update_func = function(self)
			local owner = self:owner()
			local card = owner:field_card(1)

			if card ~= nil and self._is_update_value == true then
				for index, value in ipairs(card.tags) do
					if value == "DAMAGE_EQUALS_POWER" then
						self._stored_value = owner:health()
						card.damage = math.min(500, owner:max_health() - owner:health())
						user:set_field_card(1, card)
						self._is_update_value = false
					end
				end
			end

			self._is_update_value = self._stored_value ~= owner:health()
		end
	end
end

---@param user Entity
function card_init(user, props)
	return sword:create_action(user, function()
		if track_health ~= nil then track_health:eject() end

		local spells = {}
		spawn_artifact(spells, user, "MURAMASA")
		create_spell(spells, user, props, 1, 0)
		create_spell(spells, user, props, 2, 0)

		Resources.play_audio(AUDIO)
	end)
end

---@param user Entity
function create_spell(spells, user, props, x_offset, y_offset)
	local field = user:field()
	local h_tile = user:get_tile(user:facing(), x_offset)
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

	field:spawn(spell, tile)

	spells[#spells + 1] = spell
end

---@param user Entity
function spawn_artifact(spells, user, state)
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

	local field = user:field()
	field:spawn(fx, user:get_tile(user:facing(), 1))
end
