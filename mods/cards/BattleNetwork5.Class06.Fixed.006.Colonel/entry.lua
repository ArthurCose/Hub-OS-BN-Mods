---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local SPELL_TEXTURE = bn_assets.load_texture("melody.png")
local SPELL_ANIMATION_PATH = bn_assets.fetch_animation_path("melody.animation")

local SING_SFX = bn_assets.load_audio("toad_recital.ogg")

---@param user Entity
function card_dynamic_damage(user)
  return 60 + user:attack_level() * 20
end

local function create_spell(team, direction, hit_props)
  local spell = Spell.new(team)
  spell:set_never_flip()
  spell:set_hit_props(hit_props)
  spell:set_texture(SPELL_TEXTURE)

  local animation = spell:animation()
  animation:load(SPELL_ANIMATION_PATH)
  animation:set_state("DEFAULT")
  animation:on_frame(2, function()
    local current_tile = spell:current_tile()
    local x = current_tile:x()
    local y = current_tile:y()

    local characters = Field.find_nearest_characters(spell, function(c)
      local target_x = c:current_tile():x()

      if direction == Direction.Right and target_x <= x then
        return false
      end

      if direction == Direction.Left and target_x >= x then
        return false
      end

      return c:hittable() and c:team() ~= team
    end)

    local target_character = characters[1]
    local y_direction = Direction.None

    if target_character then
      local target_y = target_character:current_tile():y()

      if target_y < y then
        y_direction = Direction.Up
      elseif target_y > y then
        y_direction = Direction.Down
      end
    end

    local tile = spell:get_tile(Direction.join(direction, y_direction), 1)

    if tile then
      local next_spell = create_spell(team, direction, hit_props)
      Field.spawn(next_spell, tile)
    end
  end)

  animation:on_complete(function()
    spell:delete()
  end)

  spell.on_spawn_func = function()
    spell:attack_tile()
  end

  spell.on_collision_func = function()
    spell:delete()
  end

  return spell
end

---@param user Entity
function card_init(user, props)
  local action = Action.new(user)
  action:set_lockout(ActionLockout.new_sequence())

  action:create_step()

  action.on_execute_func = function()
    local hit_props = HitProps.from_card(props, user:context())

    user:set_counterable(true)

    local animation = user:animation()
    animation:set_state("CHARACTER_SING")
    animation:on_frame(2, function()
      user:set_counterable(false)
      Resources.play_audio(SING_SFX)

      local direction = user:facing()
      local tile = user:get_tile(direction, 1)

      if tile then
        local spell = create_spell(user:team(), direction, hit_props)
        Field.spawn(spell, tile)
      end
    end)

    animation:on_complete(function()
      action:end_action()
    end)
  end

  action.on_action_end_func = function()
    user:set_counterable(false)
  end

  return action
end
