-- slightly different from the anti damage poof action
-- the player will poof immediately and stay visible in this version

---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local AUDIO = bn_assets.load_audio("antidmg.ogg")
local SHURIKEN_TEXTURE = bn_assets.load_texture("shuriken.png")
local SHURIKEN_ANIMATON_PATH = bn_assets.fetch_animation_path("shuriken.animation")

local ELEVATION = 50

---@param user Entity
local function targeting(user)
  local tile

  ---@type fun(entity: Entity): boolean
  local is_ahead
  local x = user:current_tile():x()

  if user:facing() == Direction.Right then
    is_ahead = function(other)
      return other:current_tile():x() > x
    end
  else
    is_ahead = function(other)
      return other:current_tile():x() < x
    end
  end

  local enemy_filter = function(character)
    return character:team() ~= user:team() and character:hittable() and is_ahead(character)
  end

  local enemy_list = Field.find_nearest_characters(user, enemy_filter)

  if #enemy_list > 0 then
    tile = enemy_list[1]:current_tile()
  end

  if not tile then
    return nil
  end

  return tile
end

---@param user Entity
---@param hit_props HitProps
---@param target_tile Tile
local function create_shuriken_spell(user, hit_props, target_tile)
  local spell = Spell.new(user:team())
  spell:set_facing(user:facing())
  spell:sprite():set_layer(-5)
  spell:set_texture(SHURIKEN_TEXTURE)

  local spell_anim = spell:animation()
  spell_anim:load(SHURIKEN_ANIMATON_PATH)
  spell_anim:set_state("FLY")

  spell:set_hit_props(hit_props)

  local total_frames = 15
  local y = user:elevation() + user:height() / 2
  local vel_y = -y / total_frames

  spell.on_update_func = function()
    if y > 0 then
      if not spell:is_moving() then
        spell:slide(target_tile, total_frames)
      end

      target_tile:set_highlight(Highlight.Solid)
    else
      local tile = spell:current_tile()

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

      y = 0
    end

    spell:set_elevation(math.floor(y))
    y = y + vel_y
  end

  return spell
end

local APPEAR_FRAMES = { { 4, 1 }, { 3, 1 }, { 2, 1 }, { 1, 1 } }
local SWING_FRAMES = { { 1, 2 }, { 2, 2 }, { 3, 2 }, { 4, 30 } }

---@param user Entity
---@param hit_props HitProps
local function create_action(user, hit_props)
  local action = Action.new(user, "CHARACTER_MOVE")
  action:override_animation_frames(APPEAR_FRAMES)

  action:set_lockout(ActionLockout.new_sequence())
  action:create_step()

  action.on_execute_func = function()
    Resources.play_audio(AUDIO, AudioBehavior.Default)

    -- disable hitbox and
    user:enable_hitbox(false)

    -- rise
    user:set_elevation(ELEVATION)

    -- poof
    local poof = bn_assets.ParticlePoof.new()
    local poof_position = user:movement_offset()
    poof_position.y = poof_position.y - user:height() / 2
    poof:set_offset(poof_position.x, poof_position.y)
    Field.spawn(poof, user:current_tile())

    -- end action with a swing animation
    local animation = user:animation()
    animation:on_complete(function()
      animation:set_state("CHARACTER_SWING_HAND", SWING_FRAMES)
      animation:on_complete(function()
        action:end_action()
      end)
      animation:on_interrupt(function()
        action:end_action()
      end)

      -- spawn shuriken
      local tile = targeting(user)

      if tile then
        local spell = create_shuriken_spell(user, hit_props, tile)
        Field.spawn(spell, user:current_tile())
      end
    end)
  end

  action.on_action_end_func = function()
    user:enable_hitbox(true)
    user:set_elevation(0)
  end

  return action
end

return create_action
