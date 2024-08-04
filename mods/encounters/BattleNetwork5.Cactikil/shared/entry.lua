local idle
local shared_folder_path = "../shared/"

local BOUNCE_SFX = Resources.load_audio(shared_folder_path .. "cactikil_bounce.ogg")
local THROW_SFX = Resources.load_audio(shared_folder_path .. "cactikil_launch.ogg")

---@param character Entity
local function create_substitute(character)
  local substitute = Obstacle.new(character:team())
  substitute:set_facing(character:facing())
  substitute:set_texture(character:texture())
  substitute:set_palette(character:palette() --[[@as string]])
  substitute:set_height(45)

  substitute.can_move_to_func = function()
    return false
  end

  substitute.on_update_func = function()
    if character:deleted() then
      substitute:delete()
    end
  end

  substitute.on_delete_func = function()
    substitute:field():spawn(Explosion.new(), substitute:current_tile())
    substitute:erase()
  end

  local anim = substitute:animation()
  anim:copy_from(character:animation())
  anim:set_state("HEADLESS")

  character:field():spawn(substitute, character:current_tile())

  return substitute
end

---@param character Entity
local function create_hit_spell(character)
  local spell = Spell.new(character:team())
  spell:set_facing(character:facing())
  spell:set_shadow(Shadow.Small)
  spell:show_shadow(true)
  spell:sprite():set_layer(5)

  spell:set_hit_props(
    HitProps.new(
      character._damage,
      Hit.Impact | Hit.Flinch | Hit.Flash,
      Element.Wood,
      character:context(),
      Drag.None
    )
  )

  spell.on_update_func = function()
    if character:deleted() then
      spell:erase()
    end
  end

  spell.can_move_to_func = function()
    return true
  end

  return spell
end

local function spawn_teleport_out_artifact(character)
  local artifact = Artifact.new()
  artifact:set_facing(character:facing())
  artifact:set_texture(Resources.load_texture(shared_folder_path .. "teleport.png"))

  artifact:load_animation(shared_folder_path .. "teleport.animation")
  local anim = artifact:animation()
  anim:set_state("SMALL_TELEPORT_FROM")
  anim:on_complete(function()
    artifact:erase()
  end)

  local char_offset = character:offset()
  local char_movement_offset = character:movement_offset()
  artifact:set_offset(char_offset.x + char_movement_offset.x * 0.5, char_offset.y + char_movement_offset.y * 0.5)

  character:field():spawn(artifact, character:get_tile())
end

local function return_to_body(character, substitute)
  local elevation = 250
  local velocity = 1

  character:set_offset(0, -elevation * 0.5)
  character:get_tile():remove_entity_by_id(character:id())
  substitute:get_tile():add_entity(character)
  character._attacking = false
  character:enable_hitbox(false)

  local animation = character:animation()
  animation:set_state("HEAD")
  animation:set_playback(Playback.Loop)

  character.on_update_func = function()
    elevation = elevation - velocity
    velocity = velocity + 1
    character:set_offset(0, -elevation * 0.5)

    if elevation < 25 then
      character:enable_hitbox(true)
      character:set_offset(0, 0)
      idle(character)
      substitute:erase()
    end
  end
end

---@param character Entity
local function begin_rolling(character)
  local animation = character:animation()
  animation:set_state("ROLLIN")
  animation:set_playback(Playback.Loop)
  character:hide()
  character._attacking = true

  local substitute = create_substitute(character)
  local spell = create_hit_spell(character)
  local counter = 0

  local start_tile = character:get_tile(character:facing(), 1)
  character:field():spawn(spell, start_tile)
  character:teleport(start_tile, function()
    character:enable_sharing_tile(true)
  end)

  local function complete()
    -- swapping the update_func to delay by one frame as
    -- the head is still moving and needs a frame to stop
    character.on_update_func = function()
      spawn_teleport_out_artifact(character)

      character:set_offset(0, 0)
      spell:erase()
      character:enable_sharing_tile(false)

      return_to_body(character, substitute)
    end
  end

  character.on_update_func = function()
    if counter == 1 then
      character:reveal()
    end

    counter = counter + 1

    if counter < 2 then
      return
    end

    local wrapped_counter = (counter) % 20
    local current_tile = character:current_tile()

    character:set_offset(0, -40 * math.sin(math.pi * wrapped_counter / 20) * 0.5)
    current_tile:attack_entities(spell)

    local offset = character:movement_offset()
    spell:set_offset(offset.x, offset.y)

    spell:get_tile():remove_entity_by_id(spell:id())
    current_tile:add_entity(spell)

    if #current_tile:find_obstacles(function() return true end) > 0 then
      complete()
      return
    end

    if character:is_moving() then
      return
    end

    if not current_tile:is_walkable() then
      complete()
      return
    end

    local dest_tile = character:get_tile(character:facing(), 1)

    if dest_tile == nil then
      complete()
      return
    end

    character:slide(dest_tile, 20, function()
      Resources.play_audio(BOUNCE_SFX)
    end)
  end
end

---@param character Entity
local function begin_attack(character)
  local action = Action.new(character, "ATTACK")

  action.on_execute_func = function()
    character:set_counterable(true)
  end

  action.on_action_end_func = function()
    character:set_counterable(false)
    Resources.play_audio(THROW_SFX)
    begin_rolling(character)
  end

  character.on_update_func = function()
  end
  character:queue_action(action)
end

idle = function(character)
  character.on_update_func = function()
  end

  local animation = character:animation()

  animation:set_state("IDLE")
  animation:set_playback(Playback.Loop)
  animation:on_complete(function()
    -- reset complete function
    animation:on_complete(function()
    end)

    local remaining_ticks = math.random(72 * 2)

    character.on_update_func = function()
      remaining_ticks = remaining_ticks - 1

      if remaining_ticks == 0 then
        begin_attack(character)
      end
    end
  end)
end

local function character_init(character)
  character:set_height(45)
  character:set_element(Element.Wood)

  character._attacking = false
  character._damage = 20
  character:set_texture(Resources.load_texture(shared_folder_path .. "battle.greyscaled.png"))
  character:load_animation(shared_folder_path .. "battle.animation")
  character:animation():set_state("INIT")

  character:add_aux_prop(StandardEnemyAux.new())

  character.can_move_to_func = function(tile)
    if character._attacking then
      return true
    end

    if not tile:is_walkable() or tile:team() ~= character:team() then
      return false
    end

    local has_character = false

    tile:find_entities(function(c)
      if Character.from(c) or Obstacle.from(c) then
        has_character = true
      end
      return false
    end)

    return not has_character
  end

  character.on_battle_start_func = function()
    idle(character)
  end
end

return character_init
