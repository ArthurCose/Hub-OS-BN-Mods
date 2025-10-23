---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local DRIP_SHOWER_TEXTURE = Resources.load_texture("drip_shower.png")
local DRIP_SHOWER_ANIM_PATH = "drip_shower.animation"

local DRIP_SHOWER_SFX = bn_assets.load_audio("drip_shower.ogg")

---@param user Entity
function card_dynamic_damage(user)
  return 20 + user:attack_level() * 10
end

---@param tile Tile?
local function spawn_tile_attack(team, hit_props, tile)
  if not tile or tile:is_edge() then return end

  local spell = Spell.new(team)
  spell:set_hit_props(hit_props)
  spell:set_tile_highlight(Highlight.Solid)

  spell.on_spawn_func = function()
    spell:attack_tile()
  end

  local i = 0
  spell.on_update_func = function()
    if i == 9 then
      spell:delete()
    end
    i = i + 1
    spell:attack_tile()
  end

  Field.spawn(spell, tile)
end

local function create_drip_shower(team, direction, hit_props)
  local spell = Spell.new(team)
  spell:set_facing(direction)
  spell:set_hit_props(hit_props)
  spell:set_texture(DRIP_SHOWER_TEXTURE)
  spell:sprite():set_layer(-3)

  local animation = spell:animation()
  animation:load(DRIP_SHOWER_ANIM_PATH)
  animation:set_state("DEFAULT")
  animation:set_playback(Playback.Loop)

  local loops = -1

  animation:on_frame(1, function()
    loops = loops + 1
    spawn_tile_attack(team, hit_props, spell:get_tile(Direction.Left, 1))
    spawn_tile_attack(team, hit_props, spell:get_tile(Direction.Right, 1))
  end)

  local function spawn_diagonal_attacks(top_direction)
    local bottom_direction = Direction.reverse(top_direction)

    spawn_tile_attack(team, hit_props, spell:get_tile(Direction.join(top_direction, Direction.Up), 1))
    spawn_tile_attack(team, hit_props, spell:get_tile(Direction.join(bottom_direction, Direction.Down), 1))
  end

  animation:on_frame(3, function()
    if loops == 2 then
      animation:set_state("DEFAULT")
      return
    end

    spawn_diagonal_attacks(direction)
    Resources.play_audio(DRIP_SHOWER_SFX, AudioBehavior.NoOverlap)
  end)

  animation:on_frame(5, function()
    spawn_tile_attack(team, hit_props, spell:get_tile(Direction.Up, 1))
    spawn_tile_attack(team, hit_props, spell:get_tile(Direction.Down, 1))
  end)

  animation:on_frame(7, function()
    spawn_diagonal_attacks(Direction.reverse(direction))
  end)

  spell.on_update_func = function()
    Resources.play_audio(DRIP_SHOWER_SFX, AudioBehavior.NoOverlap)
  end

  spell.on_delete_func = function()
    spell:hide()
    spell:erase()
  end

  return spell
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  local animation = user:animation()

  if not animation:has_state("DRIP_SHOWER_START") then
    return
  end

  local action = Action.new(user, "DRIP_SHOWER_START")
  action:set_lockout(ActionLockout.new_sequence())

  ---@type Tile?
  local original_tile

  local attack_step = action:create_step()
  local return_step = action:create_step()

  return_step.on_update_func = function()
    return_step.on_update_func = nil

    animation:set_state("CHARACTER_MOVE", { { 1, 1 }, { 2, 4 }, { 3, 1 }, { 4, 1 } })
    animation:on_complete(function()
      return_step:complete_step()

      if original_tile then
        original_tile:add_entity(user)
        user:enable_hitbox(true)
      end
    end)
  end

  local end_step = action:create_step()
  end_step.on_update_func = function()
    end_step.on_update_func = nil

    animation:set_state("CHARACTER_MOVE", { { 4, 1 }, { 3, 1 }, { 2, 4 }, { 1, 1 } })
    animation:on_complete(function()
      end_step:complete_step()
    end)
  end

  local spell

  ---@param tile Tile
  local can_move_to = function(tile)
    return (tile:is_walkable() or user:ignore_hole_tiles()) and not tile:is_reserved() and not tile:is_edge()
  end

  action.on_execute_func = function()
    user:set_counterable(true)
    original_tile = user:current_tile()
    original_tile:reserve_for(user)

    animation:on_complete(function()
      user:set_counterable(false)
      animation:set_state("DRIP_SHOWER_LOOP")
      animation:set_playback(Playback.Loop)

      local loops = -1

      animation:on_frame(1, function()
        loops = loops + 1

        if loops == 2 then
          local target_tile = user:get_tile(user:facing(), 3)

          if target_tile and can_move_to(target_tile) then
            target_tile:add_entity(user)
            user:enable_hitbox(false)

            local hit_props = HitProps.from_card(props, user:context())
            spell = create_drip_shower(user:team(), user:facing(), hit_props)
            Field.spawn(spell, user:current_tile())
          else
            attack_step:complete_step()
            return_step:complete_step()
          end
        end
      end)

      animation:on_frame(4, function()
        if loops == 7 then
          attack_step:complete_step()
          spell:delete()
        end
      end)
    end)
  end

  action.on_action_end_func = function()
    user:set_counterable(false)
    user:enable_hitbox(true)

    if original_tile then
      original_tile:add_entity(user)
      original_tile:remove_reservation_for(user)
    end

    if spell then
      spell:delete()
    end
  end

  return action
end
