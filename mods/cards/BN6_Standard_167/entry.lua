---@type BattleNetwork6.Libraries.PanelGrab
local PanelGrabLib = require("BattleNetwork6.Libraries.PanelGrab")
local bn_assets = require("BattleNetwork.Assets")

local GRAB_TEXTURE = bn_assets.load_texture("panelgrab.png")
local GRAB_ANIMATION_PATH = bn_assets.fetch_animation_path("panelgrab.animation")
local INDICATE_SFX = bn_assets.load_audio("indicate.ogg")

---@param user Entity
function card_init(user)
	local action = Action.new(user)
	action:set_lockout(ActionLockout.new_sequence())

	action.on_execute_func = function()
		local team = user:team()
		local direction = user:facing()

		local field = user:field()
		---@type Tile[]
		local stolen_tiles = {}

		for x = 0, field:width() - 1 do
			local column_stolen = false

			for y = 0, field:height() - 1 do
				local tile = field:tile_at(x, y)
				local stolen = false

				if tile and not tile:is_edge() then
					stolen = tile:team() ~= user:team() and tile:original_team() == user:team()
				end

				if stolen then
					column_stolen = true
					table.insert(stolen_tiles, tile)
				end
			end

			if column_stolen then
				field:reclaim_column(x, team)
			end
		end

		if #stolen_tiles == 0 then
			return
		end

		local indicate_step = action:create_step()

		for _, tile in ipairs(stolen_tiles) do
			local artifact = Artifact.new()
			artifact:set_texture(GRAB_TEXTURE)

			local animation = artifact:animation()
			animation:load(GRAB_ANIMATION_PATH)
			animation:set_state("GRAB")
			animation:on_complete(function()
				indicate_step:complete_step()
				artifact:erase()
			end)

			field:spawn(artifact, tile)
		end

		Resources.play_audio(INDICATE_SFX)

		-- prioritize nearest opponent player
		local target = field:find_nearest_players(user, function(player)
			return player:team() ~= user:team() and player:hittable()
		end)[1]

		if not target then
			-- switch to nearest opponent character
			target = field:find_nearest_characters(user, function(character)
				return character:team() ~= user:team() and character:hittable()
			end)[1]
		end

		if not target then
			-- nothing to do
			return
		end

		local tile = target:current_tile()

		local attack_step = action:create_step()
		local total_stolen = #stolen_tiles
		local existing_spell

		attack_step.on_update_func = function()
			if existing_spell and not existing_spell:deleted() then
				-- wait for the spell to land
				return
			end

			if total_stolen == 0 then
				attack_step:complete_step()
				return
			end

			total_stolen = total_stolen - 1

			local spell = PanelGrabLib.create_spell(team, direction)

			local hit_props = spell:copy_hit_props()
			hit_props.flags = hit_props.flags | Hit.PierceInvis | Hit.Drag
			hit_props.damage = 40
			hit_props.drag = Drag.new(target:facing_away(), field:width())
			spell:set_hit_props(hit_props)

			field:spawn(spell, tile)
			existing_spell = spell
		end
	end

	return action
end
