function card_init(user, props)
	props.package_id = "BattleNetwork6.Class01.Standard.103.Snake"

	local action = Action.from_card(user, props)
	action:on_end(function()
		local tile_list = Field.find_tiles(function(tile)
			if tile:team() ~= user:team() and tile:team() ~= Team.Other then return false end
			if not tile:is_walkable() then return false end
			tile:set_state(TileState.Grass)
			return true
		end)
	end)

	return action
end
