---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
---@type dev.konstinople.library.ai
local AiLib = require("dev.konstinople.library.ai")
local IteratorLib = AiLib.IteratorLib

local TEXTURE = Resources.load_texture("battle.grayscale.png")
local ANIMATION_PATH = "battle.animation"

local ARTIFACT_TEXTURE = bn_assets.load_texture("golmhit_artifact.png")
local ARTIFACT_ANIMATION_PATH = bn_assets.fetch_animation_path("golmhit_artifact.animation")
local FIST_SPAWN_SFX = bn_assets.load_audio("golmhit1.ogg")
local FIST_LAND_SFX = bn_assets.load_audio("golmhit2.ogg")

local DAMAGE_REDUCED_SFX = bn_assets.load_audio("damage_reduced.ogg")

---@class _BattleNetwork6.CraggerProps
---@field name string
---@field health number
---@field attack number
---@field disable_movement boolean?
---@field deletes_chips boolean?

---@param tile Tile
local function crack_tile_and_spawn_artifact(tile)
  if tile:state() == TileState.Cracked then
    tile:set_state(TileState.Broken)
  else
    tile:set_state(TileState.Cracked)
  end

  -- spawn artifact
  local artifact = Artifact.new()
  artifact:set_texture(ARTIFACT_TEXTURE)
  artifact:sprite():set_layer(-3)

  local animation = artifact:animation()
  animation:load(ARTIFACT_ANIMATION_PATH)
  animation:set_state("DEFAULT")
  animation:on_complete(function()
    artifact:erase()
  end)

  Field.spawn(artifact, tile)
end

---@param spell Entity
---@param direction Direction
local function try_attack_tile(spell, direction)
  local tile = spell:get_tile(direction, 1)

  if tile and tile:is_walkable() then
    spell:attack_tile(tile)
    crack_tile_and_spawn_artifact(tile)
  end
end

---@param character Entity
---@param warning_spell Entity?
---@param props _BattleNetwork6.CraggerProps
local function create_fist(character, warning_spell, props)
  local spell = Spell.new(character:team())
  spell:set_facing(character:facing())
  spell:set_texture(character:texture())
  spell:set_palette(character:palette())
  spell:sprite():set_layer(-1)

  spell:set_hit_props(
    HitProps.new(
      props.attack,
      Hit.Flinch | Hit.Flash | Hit.PierceGuard | Hit.PierceGround,
      Element.None,
      character:context()
    )
  )

  local animation = spell:animation()
  animation:copy_from(character:animation())
  animation:set_state("FIST")

  animation:on_frame(3, function()
    if warning_spell then
      warning_spell:delete()
      warning_spell = nil
    end

    -- always attack the tile with the fist
    spell:attack_tile()
    local current_tile = spell:current_tile()

    if not current_tile:is_walkable() then
      local artifact = bn_assets.MobMove.new("MEDIUM_START")
      Field.spawn(artifact, current_tile)
      spell:delete()
      return
    end

    crack_tile_and_spawn_artifact(current_tile)
    try_attack_tile(spell, Direction.Up)
    try_attack_tile(spell, Direction.Down)
    Resources.play_audio(FIST_LAND_SFX, AudioBehavior.Restart)
    Field.shake(6, 30)
  end)

  animation:on_complete(function()
    spell:delete()
  end)

  spell.on_spawn_func = function()
    Resources.play_audio(FIST_SPAWN_SFX, AudioBehavior.Restart)
  end

  if props.deletes_chips then
    spell.on_attack_func = function(_, other)
      local enemy = Character.from(other)

      if enemy and enemy:current_tile() == spell:current_tile() then
        enemy:remove_field_card(1)
      end
    end
  end

  spell.on_delete_func = function()
    if warning_spell then
      warning_spell:delete()
    end

    spell:erase()
  end

  return spell
end

local function create_warning()
  local spell = Spell.new()

  ---@param tile Tile?
  local function highlight_tile(tile)
    if tile then
      tile:set_highlight(Highlight.Flash)
    end
  end

  spell.on_update_func = function()
    highlight_tile(spell:current_tile())
    highlight_tile(spell:get_tile(Direction.Up, 1))
    highlight_tile(spell:get_tile(Direction.Down, 1))
  end

  return spell
end

---@param character Entity
---@param props _BattleNetwork6.CraggerProps
local function create_attack_factory(character, props)
  return function()
    local target = Field.find_nearest_characters(character, function(c)
      return c:hittable() and c:team() ~= character:team()
    end)[1]

    if not target then
      return nil
    end

    local action = Action.new(character, "ATTACK")

    local target_tile = target:current_tile()
    local warning_spell

    action.on_execute_func = function()
      warning_spell = create_warning()
      Field.spawn(warning_spell, target_tile)
    end

    action:on_anim_frame(6, function()
      local spell = create_fist(character, warning_spell, props)
      Field.spawn(spell, target_tile)

      warning_spell = nil
    end)

    action.on_action_end_func = function()
      if warning_spell then
        warning_spell:delete()
      end
    end

    return action
  end
end

---@param character Entity
---@param props _BattleNetwork6.CraggerProps
return function(character, props)
  character:set_name(props.name)
  character:set_health(props.health)
  character:set_texture(TEXTURE)
  character:load_animation(ANIMATION_PATH)

  local animation = character:animation()
  animation:set_state("CHARACTER_IDLE")
  character:set_height(53)

  character:add_aux_prop(StandardEnemyAux.new())

  -- defense logic
  local defense_rule = DefenseRule.new(DefensePriority.Body, DefenseOrder.CollisionOnly)
  local remaining_blink = 0

  defense_rule.filter_func = function(hit_props)
    if hit_props.flags & Hit.Drain ~= 0 then
      return hit_props
    end

    if hit_props.element == Element.Break or hit_props.secondary_element == Element.Break or hit_props.flags & Hit.PierceGuard ~= 0 then
      character:delete()
      return hit_props
    end

    if hit_props.damage > 1 then
      remaining_blink = 24
      Resources.play_audio(DAMAGE_REDUCED_SFX, AudioBehavior.Restart)
    end

    return hit_props
  end

  character:add_aux_prop(
    AuxProp.new()
    :require_hit_flags_absent(Hit.Drain)
    :decrease_hit_damage("DAMAGE / 2")
  )

  character.on_update_func = function()
    if remaining_blink <= 0 then return end

    remaining_blink = remaining_blink - 1

    if (remaining_blink // 2) % 2 == 1 then
      character:set_color(Color.new(200, 0, 0))
    end
  end

  character:add_defense_rule(defense_rule)

  -- ai
  local ai = AiLib.new_ai(character)

  local attack_factory = create_attack_factory(character, props)

  local plan = ai:create_plan()
  plan:set_action_iter_factory(function()
    return IteratorLib.chain(
      IteratorLib.take(1, function() return Action.new(character, "CHARACTER_IDLE") end),
      -- random movement
      IteratorLib.short_circuiting_chain(
        IteratorLib.take(1, function()
          if props.disable_movement then
            return nil
          end

          if math.random(2) == 1 then
            return nil
          end

          return bn_assets.MobMoveAction.new(character, "BIG")
        end),
        -- short idle break after moving
        IteratorLib.take(1, function() return Action.new(character, "CHARACTER_IDLE") end)
      ),
      -- attack
      IteratorLib.take(1, attack_factory)
    )
  end)
end
