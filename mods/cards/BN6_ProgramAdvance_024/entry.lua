---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
local AUDIO = bn_assets.load_audio("antidmg.ogg")
local SHURIKEN_TEXTURE = bn_assets.load_texture("shuriken.png")
local SHURIKEN_ANIMATON_PATH = bn_assets.fetch_animation_path("shuriken.animation")

function card_init(user, props)
  local action = Action.new(user)

  action:set_lockout(ActionLockout.new_sequence()) --Sequence lockout required to use steps & avoid issues with idle
  action.on_execute_func = function()
    local antidamage_rule = DefenseRule.new(DefensePriority.Trap, DefenseOrder.CollisionOnly)
    local activated = false

    local context = user:context()

    antidamage_rule.defense_func = function(defense, _, _, hit_props)
      if defense:damage_blocked() then
        return
      end

      if activated then
        if hit_props.flags & Hit.Drain == 0 then
          -- block all impact damage while we're waiting for the action to complete
          defense:block_damage()
        end
        return
      end

      --Simulate cursor removing traps
      if hit_props.element == Element.Cursor or hit_props.secondary_element == Element.Cursor then
        user:remove_defense_rule(antidamage_rule)
        return
      end

      if hit_props.damage >= 10 and hit_props.flags & Hit.Drain == 0 then
        defense:block_damage()
        user:queue_action(poof_user(user, context, props, antidamage_rule))
        activated = true
      end
    end

    user:add_defense_rule(antidamage_rule)
  end

  return action
end

---@param owner Entity
---@param context AttackContext
---@param props CardProperties
local function create_spawner(owner, context, props)
  local spell = Spell.new(owner:team())
  spell:set_owner(owner)

  local STARTUP = 24

  local time = 0
  local spawned = 0
  spell.on_update_func = function()
    time = time + 1

    if time < STARTUP then
      return
    end

    spell:set_tile_highlight(Highlight.None)

    local relative_time = (time - STARTUP) % 24

    if relative_time == 0 then
      if spawned >= 10 then
        spell:delete()
        return
      end

      local tile = targeting(spell)

      if tile then
        spell:current_tile():remove_entity(spell)
        tile:add_entity(spell)
      end
    end

    if relative_time < 16 then
      spell:set_tile_highlight(Highlight.Solid)
    end

    if relative_time == 8 then
      spawn_shuriken_spell(spell, context, props, spell:current_tile())
      spawned = spawned + 1
    end
  end

  Field.spawn(spell, 0, 0)
end

---@param user Entity
---@param context AttackContext
---@param props CardProperties
---@param defense_rule DefenseRule
function poof_user(user, context, props, defense_rule)
  local action = Action.new(user, "CHARACTER_MOVE")
  action:override_animation_frames({ { 1, 1 }, { 2, 1 }, { 3, 1 }, { 4, 1 } })
  local executed = false

  action:set_lockout(ActionLockout.new_sequence()) --Sequence lockout required to use steps & avoid issues with idle
  action.on_execute_func = function()
    executed = true
    Resources.play_audio(AUDIO, AudioBehavior.Default)

    -- disable hitbox
    user:enable_hitbox(false)
    create_spawner(user, context, props)

    local cooldown = 60
    local step1 = action:create_step()
    step1.on_update_func = function(self)
      if cooldown <= 0 then
        self:complete_step()
      else
        cooldown = cooldown - 1
      end
    end
  end

  action:add_anim_action(3, function()
    local poof = bn_assets.ParticlePoof.new()
    local poof_position = user:movement_offset()
    poof_position.y = poof_position.y - user:height() / 2
    poof:set_offset(poof_position.x, poof_position.y)
    Field.spawn(poof, user:current_tile())
  end)

  action.on_animation_end_func = function()
    user:hide()
  end

  action.on_action_end_func = function()
    if executed then
      user:reveal()
      user:enable_hitbox(true)
      user:remove_defense_rule(defense_rule)
    else
      -- requeue
      user:queue_action(poof_user(user, context, props, defense_rule))
    end
  end

  return action
end

function spawn_shuriken_spell(user, context, props, tile)
  local spell = Spell.new(user:team())
  spell:set_facing(user:facing())
  spell:sprite():set_layer(-5)
  spell:set_texture(SHURIKEN_TEXTURE)
  local spell_anim = spell:animation()
  spell_anim:load(SHURIKEN_ANIMATON_PATH)
  spell_anim:set_state("FLY")

  spell:set_hit_props(
    HitProps.from_card(
      props,
      context,
      Drag.None
    )
  )

  spell:set_tile_highlight(Highlight.Solid)

  local total_frames = 7
  local increment_x = 12
  local increment_y = 11

  if spell:facing() == Direction.Left then
    increment_x = -increment_x
  end

  local x = total_frames * -increment_x
  local y = total_frames * -increment_y

  spell.on_update_func = function()
    x = x + increment_x
    y = y + increment_y

    if y > 0 then
      local tile = spell:current_tile()
      spell:set_tile_highlight(Highlight.None)

      if not tile:is_walkable() then
        spell:erase()
      else
        tile:attack_entities(spell)

        spell.on_update_func = nil

        spell_anim:set_state("SHINE")
        spell_anim:on_complete(function()
          spell:erase()
        end)
      end

      x = 0
      y = 0
    end

    spell:set_offset(x, y)
  end

  Field.spawn(spell, tile)

  local poof = bn_assets.ParticlePoof.new()
  poof:set_offset(x, y)
  poof:sprite():set_layer(-1)
  Field.spawn(poof, tile)
end

function targeting(user)
  local tile

  local enemy_filter = function(character)
    return character:team() ~= user:team() and character:hittable()
  end

  local enemy_list = nil
  enemy_list = Field.find_nearest_characters(user, enemy_filter)
  if #enemy_list > 0 then tile = enemy_list[1]:current_tile() else tile = nil end

  if not tile then
    return nil
  end

  return tile
end
