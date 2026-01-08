local bn_assets = require("BattleNetwork.Assets")
local spell_texture = bn_assets.load_texture("boomer.png")
local spell_anim_path = bn_assets.fetch_animation_path("boomer.animation")
local spell_audio = bn_assets.load_audio("boomer.ogg")

function card_init(user, props)
	local action = Action.new(user)
	action:set_lockout(ActionLockout.new_async(20))

	action.on_execute_func = function()
		local team = user:team()
		local spell = Spell.new(team)
		local facing = user:facing()

		spell:set_hit_props(HitProps.from_card(props, user:context(), Drag.None))
		spell:set_texture(spell_texture)

		local spell_anim = spell:animation()
		spell_anim:load(spell_anim_path)
		spell_anim:set_state("DEFAULT")
		spell_anim:set_playback(Playback.Loop)

		spell.on_spawn_func = function()
			Resources.play_audio(spell_audio)
		end

		spell:set_facing(facing)

		local direction = facing
		spell.on_update_func = function(self)
			local tile = self:current_tile()

			if tile:state() ~= TileState.Grass and tile:can_set_state(TileState.Grass) then
				tile:set_state(TileState.Grass)
			end

			self:attack_tile()

			if self:is_sliding() == false then
				local next_tile = tile:get_tile(direction, 1)
				if next_tile == nil or next_tile:is_edge() then
					next_tile = tile:get_tile(Direction.Up, 1)
					if next_tile == nil or next_tile:is_edge() then
						next_tile = tile:get_tile(self:facing_away(), 1)
						if next_tile == nil then
							self:erase()
							return
						else
							direction = self:facing_away()
						end
					else
						direction = Direction.Up
					end
				end

				self:slide(next_tile, 5)
			end
		end

		local start_tile;
		local start_x = 1
		local increment = 1
		local goal = Field.width()
		if facing == Direction.Left then
			start_x = Field.width()
			increment = -1
			goal = 0
		end

		for x = start_x, goal, increment do
			if start_tile ~= nil then break end
			for y = Field.height(), 1, -1 do
				if start_tile ~= nil then break end

				local tile = Field.tile_at(x, y)

				if not tile then goto continue end
				if tile:is_edge() then goto continue end

				local up_tile = tile:get_tile(Direction.Up, 1)

				if not up_tile then goto continue end
				if up_tile:is_edge() then goto continue end

				start_tile = Field.tile_at(x, y)

				::continue::
			end
		end

		if start_tile ~= nil then
			Field.spawn(spell, start_tile)
		end
	end

	return action
end
