local bn_assets = require("BattleNetwork.Assets")

---@type BombLib
local BombLib = require("dev.konstinople.library.bomb")

local bomb = BombLib.new_bomb()
bomb:set_bomb_texture(bn_assets.load_texture("bomb.png"))
bomb:set_bomb_animation_path(bn_assets.fetch_animation_path("bomb.animation"))
bomb:set_bomb_animation_state("BIGBOMB")
bomb:set_bomb_shadow(bn_assets.load_texture("bomb_shadow.png"))
bomb:set_execute_sfx(bn_assets.load_audio("lob_bomb.ogg"))

local explosion_sfx = bn_assets.load_audio("explosion_defeatedboss.ogg")

---@param user Entity
function card_init(user, props)
	local field = user:field()

	return bomb:create_action(user, function(main_tile)
		if not main_tile or not main_tile:is_walkable() then
			return
		end

		local hit_props = HitProps.from_card(
			props,
			user:context(),
			Drag.None
		)

		local center_x = main_tile:x()
		local center_y = main_tile:y()

		-- spawn explosions
		for y = center_y - 1, center_y + 1 do
			for x = center_x - 1, center_x + 1 do
				local tile = field:tile_at(x, y)

				if tile then
					local explosion = Explosion.new()
					-- don't make a sound
					explosion.on_spawn_func = nil

					field:spawn(explosion, tile)

					local spell = Spell.new(user:team())
					spell:set_facing(user:facing())
					spell:set_hit_props(hit_props)

					spell.on_update_func = function(self)
						self:attack_tile()
						self:erase()
					end

					field:spawn(spell, tile)
				end
			end
		end

		Resources.play_audio(explosion_sfx)
	end)
end
