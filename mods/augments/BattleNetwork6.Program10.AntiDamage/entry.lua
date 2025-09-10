---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
local AUDIO = bn_assets.load_audio("antidmg.ogg")
local SHURIKEN_TEXTURE = bn_assets.load_texture("shuriken.png")
local SHURIKEN_ANIMATON_PATH = bn_assets.fetch_animation_path("shuriken.animation")

local function targeting(user)
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

---@param hit_props HitProps
local function create_shuriken_spell(user, hit_props)
  local spell = Spell.new(user:team())
  spell:set_facing(user:facing())
  spell:sprite():set_layer(-5)
  spell:set_texture(SHURIKEN_TEXTURE)

  local spell_anim = spell:animation()
  spell_anim:load(SHURIKEN_ANIMATON_PATH)
  spell_anim:set_state("FLY")

  spell:set_hit_props(hit_props)

  spell:set_tile_highlight(Highlight.Solid)

  local total_frames = 15
  local increment_x = 8
  local increment_y = 12

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

  return spell
end

---@param user Entity
---@param hit_props HitProps
---@param callback fun()
local function poof_user(user, hit_props, callback)
  local action = Action.new(user, "CHARACTER_MOVE")
  action:override_animation_frames({ { 1, 1 }, { 2, 1 }, { 3, 1 }, { 4, 1 } })
  local executed = false

  action:set_lockout(ActionLockout.new_sequence()) --Sequence lockout required to use steps & avoid issues with idle
  action.on_execute_func = function()
    executed = true
    Resources.play_audio(AUDIO, AudioBehavior.Default)

    -- disable hitbox
    user:enable_hitbox(false)

    -- spawn shuriken
    local tile = targeting(user)

    if tile then
      local spell = create_shuriken_spell(user, hit_props)
      Field.spawn(spell, tile)
    end

    local time = 60
    local step1 = action:create_step()
    step1.on_update_func = function(self)
      if time <= 0 then
        self:complete_step()
      else
        time = time - 1
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
      callback()
    else
      -- requeue
      user:queue_action(poof_user(user, hit_props, callback))
    end
  end

  return action
end

---@param augment Augment
function augment_init(augment)
  local owner = augment:owner()

  local cooldown = 0

  local component = owner:create_component(Lifetime.ActiveBattle)

  component.on_update_func = function()
    if cooldown > 0 then
      cooldown = cooldown - 1
    end
  end

  augment.special_attack_func = function()
    local action = Action.new(owner, "CHARACTER_IDLE")
    action:set_lockout(ActionLockout.new_sequence())

    if cooldown > 0 then
      return action
    end

    local time = 0
    local step = action:create_step()
    step.on_update_func = function()
      time = time + 1

      if time > 30 then
        step:complete_step()
      end
    end

    local activated = false
    local defense_rule = DefenseRule.new(DefensePriority.Action, DefenseOrder.CollisionOnly)
    defense_rule.defense_func = function(defense, _, _, hit_props)
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
        owner:remove_defense_rule(defense_rule)
        return
      end

      if hit_props.damage >= 10 and hit_props.flags & Hit.Drain == 0 then
        defense:block_damage()

        local hit_props = HitProps.new(50, Hit.Flinch, Element.None, owner:context())
        local callback = function()
          owner:remove_defense_rule(defense_rule)
          cooldown = 10
        end

        owner:queue_action(poof_user(owner, hit_props, callback))
        activated = true
        cooldown = 0

        -- clear trap
        local trap_rule = DefenseRule.new(DefensePriority.Trap, DefenseOrder.CollisionOnly)
        owner:add_defense_rule(trap_rule)
        owner:remove_defense_rule(trap_rule)

        -- cancel action
        action:end_action()
      end
    end

    local executed = false

    action.on_execute_func = function()
      executed = true
      owner:add_defense_rule(defense_rule)
    end

    action.on_action_end_func = function()
      if executed then
        owner:remove_defense_rule(defense_rule)
      end

      if not activated then
        cooldown = 70
      end
    end

    return action
  end

  augment.on_delete_func = function()
    component:eject()
  end
end
