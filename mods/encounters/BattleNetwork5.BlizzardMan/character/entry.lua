-- todo: seems to break from spamming stun attacks


local BREATH_SFX = Resources.load_audio("wind.ogg")
local THUD_SFX = Resources.load_audio("thud.ogg")

---@param character Entity
local function run_after(character, frame_count, fn)
  local component = character:create_component(Lifetime.ActiveBattle)

  component.on_update_func = function()
    frame_count = frame_count - 1

    if frame_count < 0 then
      component:eject()
      fn()
    end
  end
end

---@param character Entity
local function wait_for(character, wait_fn, fn)
  local component = character:create_component(Lifetime.ActiveBattle)

  component.on_update_func = function()
    if wait_fn() then
      component:eject()
      fn()
    end
  end
end

---@param blizzardman Entity
local function teleport(blizzardman, tile, endlag, end_callback)
  if blizzardman:current_tile() == tile then
    -- no need to move
    end_callback()
    return
  end

  local anim = blizzardman:animation()

  local function teleport_in()
    anim:set_state("MOVE")
    anim:set_playback(Playback.Reverse)
    anim:on_interrupt(end_callback)
    anim:on_complete(function()
      anim:on_interrupt(function() end)
      anim:set_state("IDLE")

      if end_callback then
        local action = Action.new(blizzardman, "IDLE")
        action:set_lockout(ActionLockout.new_sequence())

        local step = action:create_step()
        step.on_update_func = function(self)
          endlag = endlag - 1

          if endlag <= 0 then
            self:complete_step()
          end
        end

        action.on_action_end_func = function()
          end_callback(true)
        end

        blizzardman:queue_action(action)
      end
    end)
  end

  anim:set_state("MOVE")
  anim:set_playback(Playback.Once)
  anim:on_interrupt(end_callback)

  anim:on_complete(function()
    if tile ~= nil then
      blizzardman:teleport(tile)
    end

    teleport_in()
  end)
end

---@param snowball Entity
local function spawn_snowball_break_artifact(snowball)
  local artifact = Artifact.new()
  artifact:set_facing(snowball:facing())
  artifact:set_texture(snowball:texture())

  local anim = artifact:animation()
  anim:copy_from(snowball:animation())
  anim:set_state("SNOWBALL_BREAKING")
  anim:apply(artifact:sprite())

  anim:on_complete(function()
    artifact:erase()
  end)

  local offset = snowball:offset()
  local movement_offset = snowball:movement_offset()
  artifact:set_offset(
    offset.x + movement_offset.x,
    offset.y + movement_offset.y
  )

  snowball:field():spawn(artifact, snowball:current_tile())
end

---@param character Entity
local function spawn_snow_hit_artifact(character)
  local artifact = Artifact.new()
  artifact:set_facing(Direction.Right)
  artifact:set_texture(Resources.load_texture("snow_artifact.png"))

  artifact:load_animation("snow_artifact.animation")
  local anim = artifact:animation()
  anim:set_state("DEFAULT")
  anim:apply(artifact:sprite())

  anim:on_complete(function()
    artifact:erase()
  end)

  local char_offset = character:offset()
  local char_tile_offset = character:movement_offset()
  artifact:set_offset(
    char_offset.x + char_tile_offset.x + (math.random(64) - 32) * 0.5,
    char_offset.y + char_tile_offset.y * 0.5
  )

  character:field():spawn(artifact, character:current_tile())
end

---@param blizzardman Entity
local function find_target(blizzardman)
  local blizzardman_team = blizzardman:team()
  local targets = blizzardman:field()
      :find_nearest_characters(blizzardman, function(character)
        return character:hittable() and character:team() ~= blizzardman_team
      end)

  return targets[1]
end

---@param blizzardman Entity
local function get_random_team_tile(blizzardman)
  local current_tile = blizzardman:current_tile()

  local tiles = blizzardman:field()
      :find_tiles(function(tile)
        return blizzardman:can_move_to(tile) and current_tile ~= tile
      end)

  if #tiles == 0 then
    return nil
  end

  return tiles[math.random(#tiles)]
end

---@param blizzardman Entity
local function get_back_tile(blizzardman, y)
  local field = blizzardman:field()
  local start_x, end_x, x_step

  if blizzardman:facing() == Direction.Left then
    start_x = field:width()
    end_x = 1
    x_step = -1
  else
    start_x = 1
    end_x = field:width()
    x_step = 1
  end

  for x = start_x, end_x, x_step do
    local tile = field:tile_at(x, y)

    if blizzardman:can_move_to(tile) then
      return tile
    end
  end

  return nil
end

---@param blizzardman Entity
local function get_front_tile(blizzardman, y)
  local field = blizzardman:field()
  local start_x, end_x, x_step

  if blizzardman:facing() == Direction.Left then
    start_x = 1
    end_x = field:width()
    x_step = 1
  else
    start_x = field:width()
    end_x = 1
    x_step = -1
  end

  for x = start_x, end_x, x_step do
    local tile = field:tile_at(x, y)

    if blizzardman:can_move_to(tile) then
      return tile
    end
  end

  return nil
end

---@param blizzardman Entity
local function create_snowball(blizzardman, damage)
  local snowball = Obstacle.new(blizzardman:team())
  snowball:set_facing(blizzardman:facing())
  snowball:set_texture(blizzardman:texture())
  snowball:set_health(100)
  snowball:set_height(36)
  snowball:enable_sharing_tile(true)

  local anim = snowball:animation()
  anim:copy_from(blizzardman:animation())
  anim:set_state("SNOWBALL")
  anim:set_playback(Playback.Loop)

  snowball:set_hit_props(HitProps.new(
    damage,
    Hit.Impact | Hit.Flash | Hit.Flinch,
    Element.Aqua,
    blizzardman:context(),
    Drag.None
  ))

  snowball.on_update_func = function()
    local current_tile = snowball:current_tile()
    current_tile:attack_entities(snowball)

    if not current_tile:is_walkable() then
      snowball:delete()
      return
    end

    if snowball:is_moving() then
      return
    end

    snowball:slide(snowball:get_tile(snowball:facing(), 1), (10))
  end

  snowball.on_attack_func = function()
    snowball:delete()
  end

  snowball.on_delete_func = function()
    spawn_snowball_break_artifact(snowball)
    snowball:erase()
  end

  snowball.can_move_to_func = function()
    return true
  end

  return snowball
end

---@param blizzardman Entity
local function kick_snowball(blizzardman, damage, end_callback)
  local anim = blizzardman:animation()
  anim:set_state("KICK")

  anim:on_frame(2, function()
    blizzardman:set_counterable(true)
  end)

  anim:on_interrupt(function()
    blizzardman:set_counterable(false)
  end)

  anim:on_frame(3, function()
    blizzardman:set_counterable(false)
    local spawn_tile = blizzardman:get_tile(blizzardman:facing(), 1)

    if spawn_tile then
      local snowball = create_snowball(blizzardman, damage)
      blizzardman:field():spawn(snowball, spawn_tile)
    end
  end)

  anim:on_complete(function()
    end_callback()
  end)
end

-- kick two snowballs from the top or bottom row to the middle (starting row preferring the same row as the player)
---@param blizzardman Entity
local function snow_rolling(blizzardman, damage, end_callback)
  local target = find_target(blizzardman)

  if not target then
    end_callback()
    return
  end

  local start_row = target:current_tile():y()

  local back_tile = get_back_tile(blizzardman, start_row)

  teleport(blizzardman, back_tile, 25, function()
    kick_snowball(blizzardman, damage, function()
      -- move randomly up/down from the start row
      local y_offset

      if math.random(2) == 1 then
        y_offset = -1
      else
        y_offset = 1
      end

      back_tile = get_back_tile(blizzardman, start_row + y_offset)

      if not back_tile then
        -- try the other way
        back_tile = get_back_tile(blizzardman, start_row - y_offset)
      end

      if back_tile then
        blizzardman:teleport(back_tile)
      end

      kick_snowball(blizzardman, damage, function()
        end_callback()
      end)
    end)
  end)
end

---@param blizzardman Entity
local function create_continuous_hitbox(blizzardman, damage)
  local spell = Spell.new(blizzardman:team())

  spell:set_hit_props(HitProps.new(
    damage,
    Hit.Impact | Hit.Flash | Hit.Flinch,
    Element.Aqua,
    blizzardman:context(),
    Drag.None
  ))

  spell.on_update_func = function()
    spell:current_tile():attack_entities(spell)
  end

  spell.can_move_to_func = function()
    return true
  end

  return spell
end

---@param blizzardman Entity
local function blizzard_breath(blizzardman, damage, end_callback)
  local target = find_target(blizzardman)

  if not target then
    end_callback()
    return
  end

  local front_tile = get_front_tile(blizzardman, target:current_tile():y())
  teleport(blizzardman, front_tile, 0, function(success)
    if not success then
      end_callback()
      return
    end

    local action = Action.new(blizzardman, "BLIZZARD_BREATH")
    local hitboxA = create_continuous_hitbox(blizzardman, damage)
    local hitboxB = create_continuous_hitbox(blizzardman, damage)

    hitboxA.on_collision_func = function(character)
      spawn_snow_hit_artifact(character)
    end

    hitboxB.on_collision_func = hitboxA.on_collision_func

    action.on_execute_func = function()
      blizzardman:set_counterable(true)
    end

    action:add_anim_action(2, function()
      Resources.play_audio(BREATH_SFX, AudioBehavior.Default)
      blizzardman:set_counterable(false)

      local facing = blizzardman:facing()
      local field = blizzardman:field()

      local tile = blizzardman:get_tile(facing, 1)
      if not tile then return end

      field:spawn(hitboxA, tile)

      tile = tile:get_tile(facing, 1)
      if not tile then return end

      field:spawn(hitboxB, tile)
    end)

    action:add_anim_action(15, function()
      hitboxA:erase()
      hitboxB:erase()
    end)

    action.on_action_end_func = function()
      blizzardman:set_counterable(false)

      if not hitboxA:deleted() then
        hitboxA:erase()
        hitboxB:erase()
      end

      end_callback()
    end

    blizzardman:queue_action(action)
  end)
end

local falling_snow_entities = {}

local function erase_falling_snow(snow)
  for i, stored_snow in ipairs(falling_snow_entities) do
    if stored_snow:id() == snow:id() then
      table.remove(falling_snow_entities, i)
      break
    end
  end

  snow:erase()
end

---@param blizzardman Entity
local function spawn_falling_snow(blizzardman, damage)
  local team = blizzardman:team()
  local field = blizzardman:field()

  local tiles = field:find_tiles(function(tile)
    if not tile:is_walkable() or tile:team() == team then
      return false
    end

    -- avoid spawning where there is already snow
    for _, stored_snow in ipairs(falling_snow_entities) do
      if stored_snow:current_tile() == tile then
        return false
      end
    end

    return true
  end)

  if #tiles == 0 then
    -- no place to spawn
    return
  end

  local tile = tiles[math.random(#tiles)]
  local snow = Obstacle.new(team)
  snow:set_facing(Direction.Left)
  snow:set_health(1)
  snow:enable_hitbox(false)
  snow:set_shadow(Shadow.Small)
  snow:show_shadow(true)
  snow:set_texture(blizzardman:texture())
  snow:set_height(18)

  local anim = snow:animation()
  anim:copy_from(blizzardman:animation())
  anim:set_state("FALLING_SNOW")
  anim:apply(snow:sprite())

  snow:set_hit_props(HitProps.new(
    damage,
    Hit.Impact | Hit.Flash | Hit.Flinch,
    Element.Aqua,
    blizzardman:context(),
    Drag.None
  ))

  local elevation = 64
  local hit_something = false
  local melting = false

  local function melt()
    if melting then
      return
    end

    melting = true

    local melting_snow = Artifact.new()
    melting_snow:set_facing(snow:facing())
    melting_snow:set_texture(snow:texture())

    local melting_anim = melting_snow:animation()
    melting_anim:copy_from(anim)
    melting_anim:set_state("MELTING_SNOW")
    melting_anim:apply(melting_snow:sprite())

    melting_anim:on_complete(function()
      melting_snow:erase()
    end)

    field:spawn(melting_snow, snow:current_tile())

    erase_falling_snow(snow)
  end

  snow.on_update_func = function()
    if elevation < 0 then
      snow:enable_hitbox(true)
      anim:set_state("LANDING_SNOW")
      snow:current_tile():attack_entities(snow)

      anim:on_complete(function()
        if hit_something then
          erase_falling_snow(snow)
        else
          anim:set_state("LANDED_SNOW")
          anim:on_complete(melt)
        end
      end)

      -- no more updating, let the animations handle that
      snow.on_update_func = function() end
      return
    end

    snow:set_elevation(elevation * 2)
    elevation = elevation - 4
  end

  snow.on_attack_func = function(character)
    hit_something = true
    spawn_snow_hit_artifact(character)
  end

  snow.on_delete_func = function()
    melt()
    snow:erase()
  end

  field:spawn(snow, tile)
  falling_snow_entities[#falling_snow_entities + 1] = snow
end

---@param blizzardman Entity
local function rolling_slider(blizzardman, damage, end_callback)
  local target = find_target(blizzardman)

  if not target then
    end_callback()
    return
  end

  local target_row = target:current_tile():y()
  local end_tile = get_back_tile(blizzardman, target_row)
  teleport(blizzardman, end_tile, 5, function(success)
    if not success then
      end_callback()
      return
    end

    local anim = blizzardman:animation()
    local field = blizzardman:field()

    local hitbox = create_continuous_hitbox(blizzardman, damage)

    local action = Action.new(blizzardman, "CURLING_UP")
    action:set_lockout(ActionLockout.new_sequence())

    local curling_step = action:create_step()
    local rolling_step = action:create_step()

    action.on_execute_func = function()
      blizzardman:set_counterable(true)
      blizzardman:enable_sharing_tile(true)

      anim:on_complete(function()
        blizzardman:set_counterable(false)

        anim:set_state("ROLLING")
        anim:set_playback(Playback.Loop)

        field:spawn(hitbox, blizzardman:current_tile())
        curling_step:complete_step()
      end)
    end

    hitbox.on_update_func = function()
      hitbox:attack_tile()

      blizzardman:current_tile():remove_entity(blizzardman)
      hitbox:current_tile():add_entity(blizzardman)

      local offset = hitbox:movement_offset()
      blizzardman:set_offset(offset.x, offset.y)
    end

    rolling_step.on_update_func = function()
      local current_tile = hitbox:current_tile()

      if not current_tile:is_walkable() then
        if current_tile:is_edge() then
          blizzardman:field():shake(8, 0.4 * 60)
          Resources.play_audio(THUD_SFX, AudioBehavior.Default)

          spawn_falling_snow(blizzardman, damage)

          run_after(blizzardman, math.random(4, 18), function()
            spawn_falling_snow(blizzardman, damage)
          end)
        end

        rolling_step:complete_step()
        return
      end

      if hitbox:is_moving() then
        return
      end

      local dest = hitbox:get_tile(blizzardman:facing(), 1)
      hitbox:slide(dest, (7))
    end

    action.on_action_end_func = function()
      hitbox:erase()
      blizzardman:set_offset(0, 0)
      blizzardman:set_counterable(false)
      blizzardman:enable_sharing_tile(false)
      end_callback()
    end

    blizzardman:queue_action(action)
  end)
end

-- blizzardman's attacks come with a movement plan
-- snow_rolling comes after 3-4 movements
-- blizzard_breath comes after one movement and followed up with rolling_slider
---@param blizzardman Entity
local function pick_plan(blizzardman, plan_number, damage, callback)
  local movements, on_attack_func

  if plan_number > 1 and math.random(3) == 1 then
    -- 1/3 chance
    movements = 1
    on_attack_func = function(_blizzardman, _damage, _callback)
      blizzard_breath(_blizzardman, _damage, function()
        rolling_slider(_blizzardman, _damage, _callback)
      end)
    end
  else
    -- 2/3 chance
    movements = math.random(3, 4)
    on_attack_func = snow_rolling
  end

  local step

  step = function()
    if movements == 0 then
      on_attack_func(blizzardman, damage, callback)
    else
      movements = movements - 1
      teleport(blizzardman, get_random_team_tile(blizzardman), 60, function()
        wait_for(blizzardman, function()
          return not blizzardman._flinching
        end, step)
      end)
    end
  end

  step()
end

---@param blizzardman Entity
function character_init(blizzardman)
  blizzardman:set_name("BlizMan")
  blizzardman:set_element(Element.Aqua)
  blizzardman:set_height(60)
  blizzardman:set_texture(Resources.load_texture("blizzardman.png"))

  local anim = blizzardman:animation()
  anim:load("blizzardman.animation")
  anim:set_state("IDLE")

  local rank = blizzardman:rank()
  local rank_to_hp = {
    [Rank.V1] = 400,
    [Rank.V2] = 1200,
    [Rank.V3] = 1600,
    [Rank.SP] = 2000
  }
  blizzardman:set_health(rank_to_hp[rank])

  local rank_to_damage = {
    [Rank.V1] = 20,
    [Rank.V2] = 40,
    [Rank.V3] = 60,
    [Rank.SP] = 80
  }
  local attack_damage = rank_to_damage[rank]
  local has_plan = false
  local plan_number = 1

  blizzardman.on_update_func = function()
    if anim:state() == "CHARACTER_HIT" then
      -- flinching
      return
    end

    if not has_plan then
      pick_plan(blizzardman, plan_number, attack_damage, function()
        has_plan = false
      end)
      has_plan = true
      plan_number = plan_number + 1
    end
  end
end
