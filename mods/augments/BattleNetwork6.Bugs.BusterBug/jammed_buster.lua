-- tweaked from client/src/lua_api/battle_api/built_in/buster.lua
local JammedBuster = {}

---@param user Entity
JammedBuster.new = function(user)
  local card_action = Action.new(user, "CHARACTER_SHOOT")
  local context = user:context()
  local rapid_level = user:rapid_level()

  -- override animation

  local frame_data = { { 1, 1 }, { 2, 2 }, { 3, 2 }, { 1, 1 } }

  card_action:override_animation_frames(frame_data)

  -- setup buster attachment
  local buster_attachment = card_action:create_attachment("BUSTER")

  local buster_sprite = buster_attachment:sprite()
  buster_sprite:set_texture(user:texture())
  buster_sprite:set_layer(-2)
  buster_sprite:use_root_shader()
  buster_sprite:set_palette(user:palette())

  local buster_animation = buster_attachment:animation()
  buster_animation:copy_from(user:animation())
  buster_animation:set_state("BUSTER", frame_data)

  -- spell
  local cooldown_table = {
    { 5, 9, 13, 17, 21, 25 },
    { 4, 8, 11, 15, 18, 21 },
    { 4, 7, 10, 13, 16, 18 },
    { 3, 5, 7,  9,  11, 13 },
    { 3, 4, 5,  6,  7,  8 }
  }

  rapid_level = math.max(math.min(rapid_level, #cooldown_table), 1)

  local cooldown = cooldown_table[rapid_level][6]
  local elapsed_frames = 0
  local spell_erased_frame = 0

  local spell = Spell.new(user:team())
  local can_move = false

  spell:set_facing(user:facing())

  card_action.on_update_func = function()
    if spell_erased_frame == 0 and spell:will_erase_eof() then
      spell_erased_frame = elapsed_frames
    end

    elapsed_frames = elapsed_frames + 1

    if spell_erased_frame > 0 and elapsed_frames - spell_erased_frame >= cooldown then
      user:animation():resume()
    end

    if can_move then
      local motion_x = 0
      local motion_y = 0

      if user:input_has(Input.Held.Left) then
        motion_x = motion_x - 1
      end

      if user:input_has(Input.Held.Right) then
        motion_x = motion_x + 1
      end

      if user:input_has(Input.Held.Up) then
        motion_y = motion_y - 1
      end

      if user:input_has(Input.Held.Down) then
        motion_y = motion_y + 1
      end

      if (motion_x ~= 0 and user:can_move_to(user:get_tile(Direction.Right, motion_x))) or
          (motion_y ~= 0 and user:can_move_to(user:get_tile(Direction.Down, motion_y))) then
        card_action:end_action()
      end
    end
  end

  local sfx = Resources.load_audio("jammed_buster.ogg");

  card_action:add_anim_action(2, function()
    Resources.play_audio(sfx);

    local field = user:field()

    spell:set_hit_props(HitProps.new(
      0,
      Hit.None,
      Element.None,
      context,
      Drag.None
    ))

    local tiles_travelled = 1
    local move_timer = 0

    spell.on_update_func = function()
      spell:get_tile():attack_entities(spell)

      move_timer = move_timer + 1

      if move_timer < 2 then
        return
      end

      local tile = spell:get_tile(spell:facing(), 1)

      if tile then
        tiles_travelled = tiles_travelled + 1
        spell:teleport(tile)
      else
        spell:delete()
      end

      move_timer = 0
    end

    spell.on_collision_func = function()
      spell:delete()
    end

    spell.on_delete_func = function()
      -- JammedBuster specific: adding one to tiles_travelled
      local calculated_cooldown = cooldown_table[rapid_level][tiles_travelled + 1]

      if calculated_cooldown ~= nil then
        cooldown = calculated_cooldown
      end

      spell:erase()
    end

    field:spawn(spell, user:current_tile())
  end)

  -- flare attachment
  card_action:add_anim_action(3, function()
    local flare_attachment = buster_attachment:create_attachment("ENDPOINT")

    -- no sprite, we only really care about the animation timing
    local animation = flare_attachment:animation()
    animation:load(Resources.game_folder() .. "resources/scenes/battle/buster_flare.animation")
    animation:set_state("DEFAULT")
    animation:on_frame(3, function()
      can_move = true
    end)
  end)

  card_action:add_anim_action(4, function()
    local animation = user:animation()

    animation:on_interrupt(function()
      animation:resume()
    end)

    animation:pause()
  end)

  card_action.on_animation_end_func = function()
    card_action:end_action()
  end

  return card_action
end

return JammedBuster
