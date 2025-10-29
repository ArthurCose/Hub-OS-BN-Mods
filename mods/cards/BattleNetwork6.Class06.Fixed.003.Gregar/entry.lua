---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local SFX = bn_assets.load_audio("slashman_spin.ogg")

---@param user Entity
function card_dynamic_damage(user)
  return 80 + user:attack_level() * 20
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  local action = Action.new(user, "ROLLING_SLASH_START")
  action:set_lockout(ActionLockout.new_sequence())

  local startup_step = action:create_step()

  ---@type Tile?
  local original_tile
  local animation = user:animation()

  local defense_rule
  local spell

  action.on_execute_func = function()
    original_tile = user:current_tile()
    original_tile:reserve_for(user)

    user:set_counterable(true)

    spell = Spell.new(user:team())
    spell:set_hit_props(HitProps.from_card(props, user:context()))

    animation:on_complete(function()
      user:set_counterable(false)

      defense_rule = DefenseRule.new(DefensePriority.Last, DefenseOrder.CollisionOnly)
      defense_rule.defense_func = function(defense)
        defense:block_damage()
      end

      user:add_defense_rule(defense_rule)

      animation:set_state("ROLLING_SLASH_LOOP")
      animation:set_playback(Playback.Loop)

      Resources.play_audio(SFX)

      startup_step:complete_step()
    end)
  end

  action.can_move_to_func = function(tile)
    return not tile:is_edge()
  end

  local spin_step = action:create_step()

  local VERTICAL_DURATION = 6
  local HORIZONTAL_DURATION = 10
  local turns = 0

  local function get_next_direction()
    if turns == 0 then
      return Direction.Down
    end

    if turns == 1 then
      -- see if we should move forward or turn to hit enemies above us
      local found_enemy = false
      local current_tile = user:current_tile()

      for y = 1, current_tile:y() - 1 do
        local above_tile = Field.tile_at(current_tile:x(), y)

        if not above_tile then
          goto continue
        end

        above_tile:find_characters(function(e)
          if e:team() ~= user:team() and e:hittable() then
            found_enemy = true
          end
          return false
        end)

        if found_enemy then
          break
        end

        ::continue::
      end

      if found_enemy then
        turns = turns + 1
      else
        return user:facing()
      end
    end

    if turns == 2 then
      -- move up until we hit the edge
      return Direction.Up
    end

    if not original_tile then
      return nil
    end

    -- head back to the original tile
    local current_tile = user:current_tile()

    if original_tile:x() < current_tile:x() then
      return Direction.Left
    elseif original_tile:x() > current_tile:x() then
      return Direction.Right
    elseif original_tile:y() > user:current_tile():y() then
      return Direction.Down
    elseif original_tile:y() < user:current_tile():y() then
      return Direction.Up
    end

    return nil
  end

  ---@param tile Tile
  local function contains_blocking_obstacle(tile)
    local result = false

    tile:find_obstacles(function(obstacle)
      if tile:reserve_count_for(obstacle) > 0 then
        result = true
      end

      return false
    end)

    return result
  end

  spin_step.on_update_func = function()
    local current_tile = user:current_tile()

    spell:attack_tile(current_tile)

    if user:is_moving() then
      return
    end

    if not current_tile:is_walkable() or contains_blocking_obstacle(current_tile) then
      -- avoid getting stuck in a hole panel
      if original_tile then
        original_tile:add_entity(user)
      end

      spin_step:complete_step()
      return
    end

    local next_tile

    while true do
      local next_direction = get_next_direction()

      if not next_direction then
        -- nowhere to go? we must've returned to our original tile
        if original_tile then
          original_tile:add_entity(user)
        end

        spin_step:complete_step()
        return
      end

      next_tile = user:get_tile(next_direction, 1)

      if next_tile and not next_tile:is_edge() then
        break
      end

      turns = turns + 1
    end

    if next_tile and next_tile:x() == current_tile:x() then
      user:slide(next_tile, VERTICAL_DURATION)
    else
      user:slide(next_tile, HORIZONTAL_DURATION)
    end
  end

  local end_step = action:create_step()
  end_step.on_update_func = function()
    end_step.on_update_func = nil

    animation:set_state("ROLLING_SLASH_END")
    animation:on_complete(function()
      end_step:complete_step()
    end)
  end

  action.on_action_end_func = function()
    if original_tile then
      original_tile:remove_reservation_for(user)
      original_tile:add_entity(user)
    end

    user:set_counterable(false)

    if defense_rule then
      user:remove_defense_rule(defense_rule)
    end

    if spell then
      spell:delete()
    end
  end

  return action
end
