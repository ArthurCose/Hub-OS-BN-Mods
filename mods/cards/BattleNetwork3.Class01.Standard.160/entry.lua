local bn_assets = require("BattleNetwork.Assets")
local AUDIO = bn_assets.load_audio("break.ogg")

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_IDLE")

	action:set_lockout(ActionLockout.new_sequence())

	local tile_list = {}

	action.on_execute_func = function(self, user)
		local occupied_func = function(ent)
			if Spell.from(ent) ~= nil then return false end
			if Artifact.from(ent) ~= nil then return false end
			return true
		end

		for x = 0, Field.width(), 1 do
			for y = 0, Field.height(), 1 do
				local tile = Field.tile_at(x, y)

				-- Tile must exist to be operated upon
				if not tile then goto continue end

				-- Cannot break tiles that are occupied.
				if #tile:find_entities(occupied_func) > 0 then goto continue end

				if tile:can_set_state(TileState.Broken) then
					table.insert(tile_list, tile)
				end
				::continue::
			end
		end

		local shuffled = {}

		for i, v in ipairs(tile_list) do
			local pos = math.random(1, #shuffled + 1)
			table.insert(shuffled, pos, v)
		end

		local step1 = self:create_step()

		local cooldown = 0

		local change_index = 1

		step1.on_update_func = function(self)
			if change_index > #shuffled then
				self:complete_step()
				return
			end

			if cooldown <= 0 then
				Resources.play_audio(AUDIO)

				-- Order is entity, tile
				Field.spawn(bn_assets.ParticlePoof.new(), shuffled[change_index])

				shuffled[change_index]:set_state(TileState.Broken)

				cooldown = 4

				change_index = change_index + 1
			else
				cooldown = cooldown - 1
			end
		end
	end
	return action
end
