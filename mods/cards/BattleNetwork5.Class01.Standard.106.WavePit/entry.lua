local battle_helpers = require("Battle.Helpers")
local bn_assets = require("BattleNetwork.Assets")

local AUDIO = Resources.load_audio("Wave.ogg")

local TEXTURE = Resources.load_texture("ElemWaves.png")

local ANIM


function card_init(user, props)
	local action = Action.new(user)

	local step = action:create_step()

	--action:set_lockout(ActionLockout.new_sequence())

	action.on_execute_func = function(self, user)
		local team = user:team()
		local facing = user:facing()
		local tile1 = user:get_tile(facing, 1)
		local tile2 = tile1:get_tile(Direction.Up, 1)
		local tile3 = tile1:get_tile(Direction.Down, 1)

		local tile_forwards
		local tile_up
		local tile_down



		local tilestates = {
			TileState.Sea,
			TileState.Lava,
			TileState.Grass,
			TileState.Magnet
		}


		local tile_index = 1


		for _, value in ipairs(props.tags) do
			if value == "WavePit" then
				tile_index = 1
				ANIM = "AQUA"
			elseif value == "RedWave" then
				tile_index = 2
				ANIM = "FIRE"
			elseif value == "MudWave" then
				tile_index = 3
				ANIM = "WOOD"
			elseif value == "MagWave" then
				tile_index = 4
				ANIM = "ELEC"
			end
		end




		for i = tile1:x(), Field.width() do
			if i == nil or tile1:y() == nil then break end
			local check_tile = Field.tile_at(i, tile1:y())
			if check_tile ~= nil and check_tile:state() == tilestates[tile_index] then
				tile_forwards = check_tile
				break
			end
		end

		for i = tile1:x(), Field.width() do
			if i == nil or tile1:y() + 1 == nil then break end
			local check_tile = Field.tile_at(i, tile1:y() + 1)
			if check_tile ~= nil and check_tile:state() == tilestates[tile_index] then
				tile_down = check_tile
				break
			end
		end

		for i = tile1:x(), Field.width() do
			if i == nil or tile1:y() - 1 == nil then break end
			local check_tile = Field.tile_at(i, tile1:y() - 1)
			if check_tile ~= nil and check_tile:state() == tilestates[tile_index] then
				tile_up = check_tile
				break
			end
		end

		if tile_forwards ~= nil and tile_forwards:state() == tilestates[tile_index] then
			local movement = false
			create_attack(user, props, team, facing, tile_forwards)
			if tilestates[tile_index] ~= TileState.Broken then
				tile_forwards:set_state(TileState.Normal)
			end
		end
		if tile_down ~= nil and tile_down:state() == tilestates[tile_index] then
			local movement = false
			create_attack(user, props, team, facing, tile_down)
			if tilestates[tile_index] ~= TileState.Broken then
				tile_down:set_state(TileState.Normal)
			end
		end
		if tile_up ~= nil and tile_up:state() == tilestates[tile_index] then
			local movement = false
			create_attack(user, props, team, facing, tile_up, movement)
			if tilestates[tile_index] ~= TileState.Broken then
				tile_up:set_state(TileState.Normal)
			end
		end
	end
	return action
end

function create_attack(user, props, team, facing, tile, movement)
	local spell = Spell.new(team)

	spell:set_facing(facing)



	spell:set_texture(TEXTURE)

	local spell_anim = spell:animation()

	local spell_sprite = spell:sprite()
	spell:set_tile_highlight(Highlight.Solid)
	spell_anim:load("ElemWaves.animation")
	spell_anim:apply(spell_sprite)
	spell_sprite:set_layer(-3)


	spell_anim:set_state(ANIM)
	spell_anim:set_playback(Playback.Loop)



	Resources.play_audio(AUDIO)



	spell:set_hit_props(
		HitProps.from_card(
			props,
			user:context(),
			Drag.None
		)
	)

	spell.on_update_func = function(self)
		self:current_tile():attack_entities(self)
		if self:current_tile():is_edge() then
			self:delete()
		end
		if movement then
			if not self:current_tile():is_walkable() then
				self:delete()
			end
		end
	end


	Field.spawn(spell, tile)
	spell_anim:on_complete(function()
		spell:delete()
		local dest = spell:get_tile(spell:facing(), 1)

		if dest ~= nil and dest:is_edge() then
			return
		else
			movement = true
			create_attack(user, props, team, facing, dest, movement)
		end
	end)

	spell.on_collision_func = function(self, other)
		self:delete()
	end
	spell.on_delete_func = function(self)
		self:erase()
	end

	return spell
end
