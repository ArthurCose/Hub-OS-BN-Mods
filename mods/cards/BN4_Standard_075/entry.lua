local bn_assets = require("BattleNetwork.Assets")

local lance_texture = bn_assets.load_texture("bn4_spell_lance.png")
local lance_anim_path = bn_assets.fetch_animation_path("bn4_spell_lance.animation")
local lance_audio = bn_assets.load_audio("sword.ogg")

local function spawn_spell(tile, props, user)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing_away())
	spell:set_hit_props(
		HitProps.from_card(
			props,
			user:context(),
			Drag.new(tile:facing(), 1)
		)
	)

	spell:set_tile_highlight(Highlight.Solid)

	spell:sprite():set_texture(lance_texture)
	local spell_anim = spell:animation()
	spell_anim:load(lance_anim_path)
	spell_anim:set_state("DEFAULT")

	spell:set_offset(40, 0)

	spell._is_fade = false
	spell._fade_timer = 0
	spell._sprite_ref = spell:sprite()
	spell._flicker_count = 7
	spell:sprite():set_layer(-2)
	spell.on_update_func = function(self)
		if self._flicker_count == 0 then
			self:erase()
			return
		end

		if self._is_fade == true then
			self._fade_timer = self._fade_timer + 1
			if self._fade_timer % 4 == 0 then
				self._sprite_ref:set_visible(not self._sprite_ref:visible())
				self._flicker_count = self._flicker_count - 1
			end
			return
		end

		local offset = self:offset()
		if offset.x > 0 then
			self:set_offset(offset.x - 8, offset.y)
		else
			self._is_fade = true
		end

		self:attack_tile()
	end

	Field.spawn(spell, tile)
end

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_IDLE")

	action:set_lockout(ActionLockout.new_async(40))

	action.on_execute_func = function(self, user)
		local x = Field.width() - 2

		if user:facing() == Direction.Left then
			x = 1
		end

		for y = 0, Field.height() - 1 do
			local tile = Field.tile_at(x, y)

			if tile and not tile:is_edge() then
				spawn_spell(tile, props, user)
			end
		end

		Resources.play_audio(lance_audio)
	end
	return action
end
