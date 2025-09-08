---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
---@type dev.konstinople.library.ai
local AiLib = require("dev.konstinople.library.ai")
local IteratorLib = AiLib.IteratorLib

local TEXTURE = Resources.load_texture("battle.grayscale.png")
local ANIMATION_PATH = "battle.animation"

local SPELL_TEXTURE = Resources.load_texture("spell.png")
local SPELL_ANIMATION_PATH = "spell.animation"

-- local CURSOR_SFX = bn_assets.load_audio("cursor_lockon.ogg")
local SHOOT_SFX = bn_assets.load_audio("spreader2.ogg")


---@class _BattleNetwork6.PiranhaProps
---@field health number
---@field attack number
---@field idle_steps number
---@field gape_duration number
---@field cursor_frames_per_tile number

---@param character Entity
---@param props _BattleNetwork6.PiranhaProps
local function create_cursor(character, props)
  local spell = Spell.new(character:team())
  spell:set_facing(character:facing())
  spell:set_texture(SPELL_TEXTURE)
  spell:set_elevation(16)

  local animation = spell:animation()
  animation:load(SPELL_ANIMATION_PATH)
  animation:set_state("CURSOR")

  -- disabling cursor audio since it seems to just be annoying
  -- spell.on_spawn_func = function()
  --   Resources.play_audio(CURSOR_SFX, AudioBehavior.NoOverlap)
  -- end

  spell.on_update_func = function()
    if character:deleted() then
      spell:delete()
    end

    local next_tile = spell:get_tile(character:facing(), 1)

    if not next_tile then
      spell:delete()
      return
    end

    -- search for enemies
    local found_enemy = false

    spell:current_tile():find_characters(function(c)
      if c:team() ~= spell:team() then
        found_enemy = true
      end

      return false
    end)

    if found_enemy then
      -- lock on and alert team
      spell.on_update_func = nil
      spell:cancel_movement()
      animation:set_state("CURSOR_LOCK_ON")
      animation:on_complete(function()
        spell:delete()

        Field.find_characters(function(c)
          if c:team() == spell:team() then
            c:apply_status(Hit.EnemyAlert, 1)
          end

          return false
        end)
      end)

      return
    end

    -- continue moving
    if not spell:is_moving() then
      spell:slide(next_tile, props.cursor_frames_per_tile)
    end
  end

  return spell
end

---@param character Entity
---@param props _BattleNetwork6.PiranhaProps
local function create_search_factory(character, props)
  local animation = character:animation()

  return function()
    local action = Action.new(character, "START_SEARCH")
    action:set_lockout(ActionLockout.new_sequence())

    local cursor

    local start_step = action:create_step()
    local search_step = action:create_step()
    local end_step = action:create_step()

    search_step.on_update_func = function()
      if cursor and not cursor:deleted() then
        return
      end

      search_step:complete_step()

      animation:set_state("START_SEARCH")
      animation:set_playback(Playback.Reverse)
      animation:on_complete(function()
        end_step:complete_step()
      end)
    end

    action.on_execute_func = function()
      animation:on_complete(function()
        start_step:complete_step()
        local tile = character:get_tile(character:facing(), 1)

        if tile then
          cursor = create_cursor(character, props)
          Field.spawn(cursor, tile)
        end
      end)
    end

    action.on_action_end_func = function()
      if cursor and not cursor:deleted() then
        cursor:delete()
      end
    end

    return action
  end
end

---@param character Entity
---@param props _BattleNetwork6.PiranhaProps
local function create_arrow(character, props)
  local spell = Spell.new(character:team())
  spell:set_facing(character:facing())
  spell:set_hit_props(
    HitProps.new(
      props.attack,
      Hit.Flinch | Hit.Flash,
      Element.Aqua,
      character:context()
    )
  )
  spell:set_elevation(25)
  spell:set_texture(SPELL_TEXTURE)
  spell:set_tile_highlight(Highlight.Solid)

  local animation = spell:animation()
  animation:load(SPELL_ANIMATION_PATH)
  animation:set_state("ARROW")

  spell.on_spawn_func = function()
    Resources.play_audio(SHOOT_SFX, AudioBehavior.NoOverlap)
  end

  spell.on_collision_func = function()
    spell:delete()

    local particle = bn_assets.HitParticle.new(
      "AQUA",
      spell:movement_offset().x,
      -spell:elevation() + math.random(-16, 16)
    )

    Field.spawn(particle, spell:current_tile())
  end

  spell.on_update_func = function()
    spell:attack_tile()

    if spell:is_moving() then
      return
    end

    local next_tile = spell:get_tile(character:facing(), 1)

    if not next_tile then
      spell:delete()
      return
    end

    spell:slide(next_tile, 6)
  end

  return spell
end

---@param character Entity
---@param props _BattleNetwork6.PiranhaProps
local function create_shoot_action(character, props)
  local action = Action.new(character, "SHOOT_STARTUP")
  action:set_lockout(ActionLockout.new_sequence())

  local animation = character:animation()

  local startup_step = action:create_step()
  local wait_step = action:create_step()
  local end_step = action:create_step()

  local wait_time = 0
  wait_step.on_update_func = function()
    wait_time = wait_time + 1

    if wait_time < props.gape_duration then
      return
    end

    wait_step:complete_step()

    animation:set_state("SHOOT_END")
    animation:on_complete(function()
      end_step:complete_step()
    end)
  end

  action.on_execute_func = function()
    animation:on_complete(function()
      animation:set_state("SHOOT")
      animation:on_complete(function()
        animation:set_state("SHOOT_WAIT")
        startup_step:complete_step()

        local tile = character:get_tile(character:facing(), 1)

        if tile then
          local spell = create_arrow(character, props)
          Field.spawn(spell, tile)
        end
      end)
    end)
  end

  return action
end

---@param character Entity
---@param props _BattleNetwork6.PiranhaProps
return function(character, props)
  character:set_element(Element.Aqua)
  character:set_health(props.health)
  character:ignore_negative_tile_effects()
  character:set_texture(TEXTURE)
  character:load_animation(ANIMATION_PATH)
  local animation = character:animation()
  character:set_height(42)

  character.on_idle_func = function()
    animation:set_state("CHARACTER_IDLE")
    animation:set_playback(Playback.Loop)
  end

  character:set_idle()

  character:add_aux_prop(StandardEnemyAux.new())

  character:register_status_callback(Hit.EnemyAlert, function()
    character:cancel_actions()
    animation:set_state("SHOOT_STARTUP")
    character:queue_action(create_shoot_action(character, props))
  end)

  local move_factory = function()
    return
        bn_assets.MobMoveAction.new(character, "MEDIUM", function()
          local current_tile = character:current_tile()
          local tiles = Field.find_tiles(function(tile)
            return
                tile ~= current_tile and
                tile:x() == current_tile:x() and
                character:can_move_to(tile)
          end)

          if #tiles == 0 then
            return nil
          end

          return tiles[math.random(#tiles)]
        end)
  end
  local idle_factory = function() return Action.new(character, "CHARACTER_IDLE") end
  local search_factory = create_search_factory(character, props)

  local ai = AiLib.new_ai(character)
  local plan = ai:create_plan()
  plan:set_action_iter_factory(function()
    return IteratorLib.chain(
      IteratorLib.take(1, move_factory),
      IteratorLib.take(1, search_factory),
      IteratorLib.take(props.idle_steps, idle_factory)
    )
  end)
end
