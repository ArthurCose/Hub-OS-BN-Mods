local bn_assets = require("BattleNetwork.Assets")

local buster_texture = Resources.load_texture("LineBusterAqua.png")
local buster_anim_path = "LineBuster.animation"

local spell_texture = bn_assets.load_texture("aqua_tower.png")
local spell_anim_path = bn_assets.fetch_animation_path("aqua_tower.animation")

local audio = bn_assets.load_audio("dust_chute2.ogg")

---@param actor Entity
---@param props CardProperties

local function create_tower(user, hit_props)
	local spell = Spell.new(user:team())
	spell:set_facing(user:facing())
	spell:set_hit_props(hit_props)

	spell:set_texture(spell_texture)

	spell:set_offset(0, 0)

	local spell_anim = spell:animation()
	spell_anim:load(spell_anim_path)

	spell_anim:set_state("SPAWN")
	-- spawn chaining behavior similar to FireMan boss towers: look for nearest enemy
	-- and spawn the next tower ahead (adjusting vertical position towards the enemy)
	local SPAWN_DELAY = 30

	local function find_next_tower_tile(spell, prev_tile, direction)
		local x = prev_tile:x()
		local y = prev_tile:y()

		local direction_filter

		if direction == Direction.Left then
			direction_filter = function(e) return e:current_tile():x() < x end
		else
			direction_filter = function(e) return e:current_tile():x() > x end
		end

		local enemies = Field.find_nearest_characters(spell, function(e)
			return direction_filter(e) and e:hittable() and e:team() ~= spell:team()
		end)

		local enemy_y = (enemies[1] and enemies[1]:current_tile():y()) or y

		if enemy_y > y then
			return prev_tile:get_tile(Direction.join(direction, Direction.Down), 1)
		elseif enemy_y < y then
			return prev_tile:get_tile(Direction.join(direction, Direction.Up), 1)
		else
			return prev_tile:get_tile(direction, 1)
		end
	end

	local spawn_counter = 0

	spell.on_update_func = function(self)
		spawn_counter = spawn_counter + 1

		-- stop chaining if this tile is broken or a hole
		local cur_tile = self:current_tile()
		if cur_tile and (cur_tile:state() == TileState.Broken or cur_tile:state() == TileState.PermaHole) then
			return
		end

		if spawn_counter == SPAWN_DELAY then
			local tile = find_next_tower_tile(self, self:current_tile(), self:facing())

			-- also stop if the next tile is broken or a hole
			if tile and tile:is_walkable() and tile:state() ~= TileState.Broken and tile:state() ~= TileState.PermaHole then
				local new = create_tower(user, hit_props)
				Resources.play_audio(audio, AudioBehavior.NoOverlap)
				Field.spawn(new, tile)
			end
		end

		self:attack_tile()
		self:current_tile():set_highlight(Highlight.Solid)
	end

	spell.can_move_to_func = function(tile)
		return true
	end



    spell_anim:on_complete(function()
    spell_anim:set_state("LOOP")
    spell_anim:set_playback(Playback.Loop)

    local i = 0

    spell_anim:on_complete(function()
      i = i + 1

      if i < 2 then
        return
      end

      spell_anim:set_state("DESPAWN")
      spell_anim:on_complete(function()
        spell:erase()
      end)
    end)
  end)

  local i = 0

	return spell
end

function card_init(actor, props)
	local FRAMES = { { 1, 2 }, { 1, 1 }, { 1, 69 } }

	local action = Action.new(actor, "CHARACTER_SHOOT")

	action:override_animation_frames(FRAMES)

	action:set_lockout(ActionLockout.new_animation())

	action.on_execute_func = function(self, user)
		local buster = self:create_attachment("BUSTER")
		local buster_sprite = buster:sprite()
		buster_sprite:set_texture(buster_texture)
		buster_sprite:set_layer(-1)
		local buster_anim = buster:animation()

		buster_anim:load(buster_anim_path)
		buster_anim:set_state("SPAWN")
		buster_anim:apply(buster_sprite)
		buster_anim:on_complete(function()
			buster_anim:set_state("ATTACK_LOOP")
			buster_anim:set_playback(Playback.Loop)
		end)

        local hit_props = HitProps.from_card(props, user:context())

		self:on_anim_frame(2, function()
			local spell = create_tower(actor, hit_props)

			local tile = user:get_tile(user:facing(), 1)

			if tile then
				Field.spawn(spell, tile)
				Resources.play_audio(audio, AudioBehavior.NoOverlap)
			end
		end)
	end

	return action
end