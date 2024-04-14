local bn_assets = require("BattleNetwork.Assets")

---@type BombLib
local BombLib = require("dev.konstinople.library.bomb")

local bomb = BombLib.new_bomb()
bomb:set_bomb_texture(bn_assets.load_texture("bomb.png"))
bomb:set_bomb_animation_path(bn_assets.fetch_animation_path("bomb.animation"))
bomb:set_bomb_shadow(bn_assets.load_texture("bomb_shadow.png"))
bomb:set_execute_sfx(bn_assets.load_audio("lob_bomb.ogg"))

---@param user Entity
function card_init(user, props)
	local field = user:field()

	return bomb:create_action(user, function(tile)
		if not tile or not tile:is_walkable() then
			return
		end

		-- spawn explosion
		field:spawn(Explosion.new(), tile)

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
			self:erase()
		end

		field:spawn(spell, tile)
	end)
end
