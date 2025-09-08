---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local BEES_TEXTURE = Resources.load_texture("bees.png")
local BEES_ANIMATION_PATH = "bees.animation"
local BEES_SHADOW_TEXTURE = Resources.load_texture("bees_shadow.png")
local BUSTER_TEXTURE = bn_assets.load_texture("hive_buster.png")
local BUSTER_ANIMATION_PATH = bn_assets.fetch_animation_path("hive_buster.animation")
local HIT_EFFECT_TEXTURE = bn_assets.load_texture("bn6_hit_effects.png")
local HIT_EFFECT_ANIMATION_PATH = bn_assets.fetch_animation_path("bn6_hit_effects.animation")
local BEES_SFX = bn_assets.load_audio("bees.ogg")
local GUARD_SFX = bn_assets.load_audio("guard.ogg")

local SLIDE_DURATION = 13

local direction_tests = {
  [Direction.Left] = function(enemy_tile, bees_tile)
    return enemy_tile:x() < bees_tile:x()
  end,
  [Direction.Right] = function(enemy_tile, bees_tile)
    return enemy_tile:x() > bees_tile:x()
  end,
  [Direction.Up] = function(enemy_tile, bees_tile)
    return enemy_tile:y() < bees_tile:y()
  end,
  [Direction.Down] = function(enemy_tile, bees_tile)
    return enemy_tile:y() > bees_tile:y()
  end,
}

---@param user Entity
---@param props CardProperties
local function spawn_bees(user, props)
  local spawn_tile = user:get_tile(user:facing(), 1)

  if not spawn_tile then
    return
  end

  local bees = Spell.new(user:team())
  bees:set_texture(BEES_TEXTURE)
  bees:set_shadow(BEES_SHADOW_TEXTURE)

  local animation = bees:animation()
  animation:load(BEES_ANIMATION_PATH)
  animation:set_state("DEFAULT")
  animation:set_playback(Playback.Loop)

  bees:set_hit_props(HitProps.from_card(props, user:context()))

  -- "Each swarm hits for a maximum of 5 times"
  local remaining_hits = 5

  bees.on_attack_func = function(_, entity)
    -- spawn hit artifact
    local artifact = Artifact.new()
    artifact:set_texture(HIT_EFFECT_TEXTURE)

    local animation = artifact:animation()
    animation:load(HIT_EFFECT_ANIMATION_PATH)
    animation:set_state("WOOD")
    animation:on_complete(function()
      artifact:erase()
    end)

    local x = math.random(-0.5, 0.5) * Tile:width()
    local y = math.random(Tile:height() * 2.0)
    artifact:set_offset(x, -y)

    Field.spawn(artifact, entity:current_tile())

    -- see if we should delete or attach to an enemy
    remaining_hits = remaining_hits - 1

    if remaining_hits == 0 then
      bees:delete()
    end
  end

  local direction = user:facing()
  local direction_changes = 0

  bees:set_facing(direction)

  -- initial on_update_func, handles movement
  bees.on_update_func = function()
    -- attack the current tile
    bees:attack_tile()

    if remaining_hits < 5 then
      -- hit something, try to attach to a character
      local update_func

      bees:current_tile():find_characters(function(character)
        if update_func and not character:hittable() then
          return false
        end

        local i = 1
        update_func = function()
          if character:deleted() then
            bees:delete()
          end

          -- teleport to the enemy
          character:current_tile():add_entity(bees)

          i = i + 1

          if i % 5 ~= 0 then
            bees:attack_tile()
          end
        end

        return false
      end)

      if update_func then
        bees:cancel_movement()
        bees.on_update_func = update_func
        update_func()
      else
        -- we hit something but didn't attach?
        -- delete ourselves: lazy bees
        bees:delete()
      end

      return
    end

    if bees:is_moving() then
      return
    end

    if direction_changes < 2 then
      -- target the nearest enemy

      local nearest_enemy = Field.find_nearest_characters(bees, function(character)
        return character:team() ~= bees:team() and character:hittable()
      end)[1]

      if nearest_enemy then
        local last_direction = direction

        local bees_tile = bees:current_tile()
        local enemy_tile = nearest_enemy:current_tile()

        local same_x = enemy_tile:x() == bees_tile:x()
        local same_y = enemy_tile:y() == bees_tile:y()
        local moving_horizontally = direction == Direction.Left or direction == Direction.Right

        local good_direction = direction_tests[direction](enemy_tile, bees_tile)

        if good_direction then
          -- do nothing
        elseif same_x and same_y then
          -- on the same tile as the enemy? reverse direction
          direction = Direction.reverse(direction)
        elseif moving_horizontally and not same_y then
          -- need to move vertically
          if enemy_tile:y() > bees_tile:y() then
            direction = Direction.Down
          elseif enemy_tile:y() < bees_tile:y() then
            direction = Direction.Up
          end
        else
          -- need to move horizontally
          if enemy_tile:x() > bees_tile:x() then
            direction = Direction.Right
          elseif enemy_tile:x() < bees_tile:x() then
            direction = Direction.Left
          end
        end

        if direction == Direction.Left or direction == Direction.Right then
          bees:set_facing(direction)
        end

        if last_direction ~= direction then
          direction_changes = direction_changes + 1
        end
      end
    end

    local next_tile = bees:get_tile(direction, 1)

    if next_tile then
      bees:slide(next_tile, SLIDE_DURATION)
    else
      bees:delete()
    end
  end

  Field.spawn(bees, spawn_tile)
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  local action = Action.new(user, "CHARACTER_SHOOT")
  action:override_animation_frames({ { 1, 36 } })

  local defense_rule
  -- "Begins releasing extra bees on block: 5f"
  local extra_spawn_cooldown = 5
  local extra_spawns = 0

  action.on_execute_func = function()
    Resources.play_audio(BEES_SFX)

    local attachment = action:create_attachment("BUSTER")
    attachment:sprite():set_texture(BUSTER_TEXTURE)
    local buster_animation = attachment:animation()
    buster_animation:load(BUSTER_ANIMATION_PATH)
    buster_animation:set_state("DEFAULT")
    buster_animation:on_frame(2, function()
      spawn_bees(user, props)
    end)

    defense_rule = DefenseRule.new(DefensePriority.Action, DefenseOrder.CollisionOnly)

    defense_rule.defense_func = function(defense, _, _, hit_props)
      if hit_props.element == Element.Fire or hit_props.secondary_element == Element.Fire then
        -- we can't block fire, but it doesn't remove our defense
        return
      end

      defense:block_damage()

      if defense:responded() or hit_props.flags & Hit.Drain ~= 0 then
        -- non impact
        return
      end

      defense:set_responded()

      if extra_spawn_cooldown == 0 then
        extra_spawn_cooldown = 10
        extra_spawns = extra_spawns + 1

        buster_animation:set_state("DEFAULT")
        buster_animation:on_frame(2, function()
          spawn_bees(user, props)
        end)

        -- "Any blocked attacks by the hive will send out another swarm up to 3 times,
        -- after which the chip ends early."
        if extra_spawns == 3 then
          buster_animation:on_complete(function()
            action:end_action()
          end)
        end
      end

      Resources.play_audio(GUARD_SFX)
    end

    defense_rule.on_replace_func = function()
      action:end_action()
    end

    user:add_defense_rule(defense_rule)
  end

  action.on_update_func = function()
    if extra_spawn_cooldown > 0 then
      extra_spawn_cooldown = extra_spawn_cooldown - 1
    end
  end

  action.on_action_end_func = function()
    if defense_rule then
      user:remove_defense_rule(defense_rule)
    end
  end

  return action
end
