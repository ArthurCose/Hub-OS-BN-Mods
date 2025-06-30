---@type dev.konstinople.library.ai
local Ai = require("dev.konstinople.library.ai")

local BREATH_SFX = Resources.load_audio("wind.ogg")
local THUD_SFX = Resources.load_audio("thud.ogg")

---@generic T
---@param t table<Rank, T>
---@return table<Rank, T>
local function apply_bn5_ranks(t)
  t[Rank.Alpha] = t[Rank.V2]
  t[Rank.Beta]  = t[Rank.V3]
  t[Rank.Omega] = t[Rank.SP]
  return t
end

local RANK_TO_HP = apply_bn5_ranks({
  [Rank.V1] = 400,
  [Rank.V2] = 1200,
  [Rank.V3] = 1600,
  [Rank.SP] = 2000
})

local RANK_TO_DAMAGE = apply_bn5_ranks({
  [Rank.V1] = 20,
  [Rank.V2] = 100,
  [Rank.V3] = 160,
  [Rank.SP] = 200,
})

local RANK_TO_SLIDER_DAMAGE = apply_bn5_ranks({
  [Rank.V1] = 30,
  [Rank.V2] = 120,
  [Rank.V3] = 240,
  [Rank.SP] = 300
})

local RANK_TO_FALLING_SNOW_HP = apply_bn5_ranks({
  [Rank.V1] = 5,
  [Rank.V2] = 10,
  [Rank.V3] = 15,
  [Rank.SP] = 20
})

local RANK_TO_FALLING_SNOW_COUNT = apply_bn5_ranks({
  [Rank.V1] = 2,
  [Rank.V2] = 2,
  [Rank.V3] = 3,
  [Rank.SP] = 3
})

local RANK_TO_MOVEMENT_DELAY = apply_bn5_ranks({
  [Rank.V1] = 60,
  [Rank.V2] = 40,
  [Rank.V3] = 20,
  [Rank.SP] = 10
})

local RANK_TO_BLIZZARD_BREATH_ICE = apply_bn5_ranks({
  [Rank.V1] = false,
  [Rank.V2] = true,
  [Rank.V3] = true,
  [Rank.SP] = true
})

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

---@param blizzardman Entity
---@param end_idle_duration number
---@param select_tile fun(): Tile?
local function create_move_factory(blizzardman, end_idle_duration, select_tile)
  local animation = blizzardman:animation()

  return function()
    local action = Action.new(blizzardman, "MOVE")
    action:set_lockout(ActionLockout.new_sequence())
    action:allow_auto_tile_reservation()

    local move_step = action:create_step()

    action.on_execute_func = function()
      local tile = select_tile()

      if tile == blizzardman:current_tile() then
        move_step:complete_step()
        animation:set_state("IDLE")
        return
      end

      animation:on_complete(function()
        animation:set_state("MOVE")
        animation:set_playback(Playback.Reverse)

        animation:on_complete(function()
          if tile ~= nil then
            blizzardman:teleport(tile)
          end

          move_step:complete_step()
          animation:set_state("IDLE")
        end)
      end)
    end

    local idle_time = 0

    local idle_wait_step = action:create_step()
    idle_wait_step.on_update_func = function(self)
      blizzardman:set_facing(blizzardman:current_tile():facing())
      idle_time = idle_time + 1

      if idle_time >= end_idle_duration then
        self:complete_step()
      end
    end

    return action
  end
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
---@param end_idle_duration number
local function create_random_move_factory(blizzardman, end_idle_duration)
  return create_move_factory(blizzardman, end_idle_duration, function()
    return get_random_team_tile(blizzardman)
  end)
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
---@param end_idle_duration number
local function create_back_col_setup_factory(blizzardman, end_idle_duration)
  return create_move_factory(blizzardman, end_idle_duration, function()
    local target = find_target(blizzardman)

    if not target then
      return nil
    end

    local target_row = target:current_tile():y()
    return get_back_tile(blizzardman, target_row)
  end)
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
---@param end_idle_duration number
local function create_front_col_setup_factory(blizzardman, end_idle_duration)
  return create_move_factory(blizzardman, end_idle_duration, function()
    local target = find_target(blizzardman)

    if not target then
      return nil
    end

    local target_row = target:current_tile():y()
    return get_front_tile(blizzardman, target_row)
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
local function create_snowball(blizzardman, damage)
  local snowball = Obstacle.new(blizzardman:team())
  snowball:set_facing(blizzardman:facing())
  snowball:set_texture(blizzardman:texture())
  snowball:set_health(50)
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
local function create_snow_rolling_factory(blizzardman, damage)
  return function()
    local action = Action.new(blizzardman)
    action:set_lockout(ActionLockout.new_sequence())
    action:allow_auto_tile_reservation()

    local step = action:create_step()

    action.on_execute_func = function()
      local start_row = blizzardman:current_tile():y()
      local back_tile = get_back_tile(blizzardman, start_row)

      kick_snowball(blizzardman, damage, function()
        -- move randomly up/down from the start row
        local y_offset = math.random(0, 1) * 2 - 1

        back_tile = get_back_tile(blizzardman, start_row + y_offset)

        if not back_tile then
          -- try the other way
          back_tile = get_back_tile(blizzardman, start_row - y_offset)
        end

        if back_tile then
          blizzardman:teleport(back_tile)
        end

        kick_snowball(blizzardman, damage, function()
          step:complete_step()
        end)
      end)
    end

    return action
  end
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
    spell:attack_tile()
  end

  spell.can_move_to_func = function()
    return true
  end

  return spell
end

---@param blizzardman Entity
local function create_blizzard_breath_factory(blizzardman, damage)
  return function()
    local target = find_target(blizzardman)

    if not target then
      return
    end

    local action = Action.new(blizzardman, "BLIZZARD_BREATH")
    local hitboxA = create_continuous_hitbox(blizzardman, damage)
    local hitboxB = create_continuous_hitbox(blizzardman, damage)

    local on_collision_func = function(character)
      spawn_snow_hit_artifact(character)
    end

    hitboxA.on_collision_func = on_collision_func
    hitboxB.on_collision_func = on_collision_func

    action.on_execute_func = function()
      blizzardman:set_counterable(true)
    end

    action:add_anim_action(2, function()
      Resources.play_audio(BREATH_SFX, AudioBehavior.Default)
      blizzardman:set_counterable(false)

      local facing = blizzardman:facing()
      local field = blizzardman:field()

      local spawn_ice = RANK_TO_BLIZZARD_BREATH_ICE[blizzardman:rank()]
      local function spawn_hitbox(tile, hitbox)
        if not tile then
          return
        end

        field:spawn(hitbox, tile)

        if spawn_ice then
          run_after(blizzardman, 1, function()
            tile:set_state(TileState.Ice)
          end)
        end
      end

      local tile = blizzardman:get_tile(facing, 1)

      if tile then
        spawn_hitbox(tile, hitboxA)
        tile = tile:get_tile(facing, 1)
        spawn_hitbox(tile, hitboxB)
      end
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
    end

    return action
  end
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
local function spawn_falling_snow(blizzardman)
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
  snow:set_health(RANK_TO_FALLING_SNOW_HP[blizzardman:rank()])
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
    10,
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
---@param damage number
local function create_rolling_slider_factory(blizzardman, damage)
  return function()
    local anim = blizzardman:animation()
    local field = blizzardman:field()

    local hitbox = create_continuous_hitbox(blizzardman, damage)

    local action = Action.new(blizzardman, "CURLING_UP")
    action:set_lockout(ActionLockout.new_sequence())

    local curling_step = action:create_step()
    local rolling_step = action:create_step()

    local original_tile

    action.on_execute_func = function()
      original_tile = blizzardman:current_tile()

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

          spawn_falling_snow(blizzardman)

          local count = RANK_TO_FALLING_SNOW_COUNT[blizzardman:rank()]

          for i = 0, count - 2 do
            local min_delay = 4 + i * 4
            local max_delay = 18 + i * 4
            local delay = math.random(min_delay, max_delay)

            run_after(blizzardman, delay, function()
              spawn_falling_snow(blizzardman)
            end)
          end
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
      original_tile:add_entity(blizzardman)
    end

    return action
  end
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

  blizzardman.on_idle_func = function()
    anim:set_state("IDLE")
    anim:set_playback(Playback.Loop)
  end

  local rank = blizzardman:rank()
  blizzardman:set_health(RANK_TO_HP[rank])
  local damage = RANK_TO_DAMAGE[rank]
  local slider_damage = RANK_TO_SLIDER_DAMAGE[rank]

  -- AI

  local ai = Ai.new_ai(blizzardman)

  local random_movement_factory = create_random_move_factory(blizzardman, RANK_TO_MOVEMENT_DELAY[rank])

  -- blizzard breath + rolling slider
  local blizzard_breath_setup_factory = create_front_col_setup_factory(blizzardman, 0)
  local blizzard_breath_factory = create_blizzard_breath_factory(blizzardman, damage)
  local rolling_slider_setup_factory = create_back_col_setup_factory(blizzardman, 5)
  local rolling_slider_factory = create_rolling_slider_factory(blizzardman, slider_damage)

  local breath_plan = ai:create_plan()
  breath_plan:set_usable_after(1)
  breath_plan:set_weight(1)
  breath_plan:set_action_iter_factory(function()
    return Ai.IteratorLib.chain(
      Ai.IteratorLib.take(1, random_movement_factory),
      Ai.IteratorLib.short_circuiting_chain(
        Ai.IteratorLib.take(1, blizzard_breath_setup_factory),
        Ai.IteratorLib.take(1, blizzard_breath_factory),
        Ai.IteratorLib.take(1, rolling_slider_setup_factory),
        Ai.IteratorLib.take(1, rolling_slider_factory)
      )
    )
  end)

  -- snow rolling
  local snow_rolling_setup_factory = create_back_col_setup_factory(blizzardman, 25)
  local snow_rolling_factory = create_snow_rolling_factory(blizzardman, damage)

  local kick_snow_plan = ai:create_plan()
  kick_snow_plan:set_weight(2)
  kick_snow_plan:set_action_iter_factory(function()
    return Ai.IteratorLib.chain(
      Ai.IteratorLib.take(math.random(3, 4), random_movement_factory),
      Ai.IteratorLib.short_circuiting_chain(
        Ai.IteratorLib.take(1, snow_rolling_setup_factory),
        Ai.IteratorLib.take(1, snow_rolling_factory)
      )
    )
  end)
end
