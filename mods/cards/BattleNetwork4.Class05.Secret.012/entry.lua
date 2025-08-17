local bn_assets = require("BattleNetwork.Assets")

---@type BombLib
local BombLib = require("dev.konstinople.library.bomb")

local bomb = BombLib.new_bomb()
bomb:set_bomb_texture(Resources.load_texture("grenade.png"))
bomb:set_bomb_animation_path(_folder_path .."grenade.animation")
bomb:set_bomb_shadow(bn_assets.load_texture("bomb_shadow.png"))
bomb:set_execute_sfx(bn_assets.load_audio("lob_bomb.ogg"))
bomb:enable_seeking()

---@param user Entity
function card_init(user, props)
	return bomb:create_action(user, function(tile)
		if not tile or not tile:is_walkable() then
			return
		end

		-- spawn explosion
		Field.spawn(Explosion.new(), tile)

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

		Field.spawn(spell, tile)
	end)
end
