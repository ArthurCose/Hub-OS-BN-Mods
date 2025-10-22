---@param user Entity
function card_dynamic_damage(user)
  return 20 + user:attack_level() * 20
end

local SHADOW_TEXTURE = Resources.load_texture("shadow.png")
local SHADOW_ANIM_PATH = "shadow.animation"

---@param user Entity
---@param props CardProperties
local function create_shadow(user, props)
  local shadow = Spell.new(user:team())
  shadow:set_facing(user:facing())
  shadow:set_hit_props(HitProps.from_card(props, user:context()))
  shadow:set_texture(user:texture())

  local animation = shadow:animation()
  animation:copy_from(user:animation())

  shadow:set_shadow(SHADOW_TEXTURE, SHADOW_ANIM_PATH)

  -- queue actions
  local spawn_action = Action.new(shadow, "CHARACTER_MOVE")
  spawn_action:override_animation_frames({ { 4, 2 }, { 3, 2 }, { 2, 2 }, { 1, 2 } })
  shadow:queue_action(spawn_action)

  props.package_id = "BattleNetwork6.Class01.Standard.072"
  local attack_action = Action.from_card(shadow, props) --[[@as Action]]
  shadow:queue_action(attack_action)

  -- delete after completing actions
  shadow.on_idle_func = function()
    shadow:delete()
  end

  return shadow
end

---@param user Entity
function card_init(user, props)
  local action = Action.new(user)
  action:set_lockout(ActionLockout:new_sequence())

  action.on_execute_func = function()
    local excluded_reservers = { user:id() }
    local enemies = Field.find_nearest_characters(user, function(o)
      if not o:hittable() or o:team() == user:team() then
        return false
      end

      local tile = o:get_tile(user:facing_away(), 1)

      if not tile then
        return false
      end

      return (tile:is_walkable() or user:ignoring_hole_tiles()) and not tile:is_reserved(excluded_reservers)
    end)

    if #enemies == 0 then
      return
    end

    for _, enemy in ipairs(enemies) do
      -- try to spawn on a tile that isn't reserved by the player
      local tile = enemy:get_tile(user:facing_away(), 1) --[[@as Tile]]

      if not tile:is_reserved() then
        local shadow = create_shadow(user, props)
        Field.spawn(shadow, tile)
        return
      end
    end

    -- otherwise spawn on the first enemy
    local tile = enemies[1]:get_tile(user:facing_away(), 1) --[[@as Tile]]

    local shadow = create_shadow(user, props)
    Field.spawn(shadow, tile)
  end

  return action
end
