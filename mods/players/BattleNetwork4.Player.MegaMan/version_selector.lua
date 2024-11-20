local ARROW_TEXTURE = Resources.load_texture("version_arrow.png")

---@param button CardSelectButton
---@param version_states string[]
---@param on_complete fun(string)
return function(button, version_states, on_complete)
  local player = button:owner()
  local button_sprite = button:sprite()
  local button_animation = button:animation()
  button_animation:set_state(version_states[1])

  -- create arrows
  local arrow_animation = Animation.new("version_arrow.animation")
  arrow_animation:set_state("RIGHT")

  local left_arrow = button_sprite:create_node()
  left_arrow:set_texture(ARROW_TEXTURE)
  left_arrow:set_visible(false)
  left_arrow:set_scale(-1, 1)

  local right_arrow = button_sprite:create_node()
  right_arrow:set_texture(ARROW_TEXTURE)
  right_arrow:set_visible(false)

  arrow_animation:apply(left_arrow)
  arrow_animation:apply(right_arrow)

  -- state
  local focused = false
  local just_focused = false
  local i = 1

  local function reset()
    if focused then
      player:set_card_selection_blocked(false)
      left_arrow:set_visible(false)
      right_arrow:set_visible(false)
      focused = false
    end
  end

  -- handle scripts closing card select
  local reset_component = player:create_component(Lifetime.CardSelectClose)
  reset_component.on_update_func = reset

  -- handle input
  local focused_component = player:create_component(Lifetime.Scene)
  focused_component.on_update_func = function()
    if just_focused then
      just_focused = false
      return
    end

    if not focused then
      return
    end

    local diff = 0

    if player:input_has(Input.Pulsed.Left) then
      diff = -1
    end

    if player:input_has(Input.Pulsed.Right) then
      diff = diff + 1
    end

    if diff ~= 0 then
      Resources.play_audio(Resources.game_folder() .. "resources/sfx/cursor_move.ogg")

      if diff > 0 then
        -- increment and wrap
        i = i % #version_states + 1
      elseif i <= 1 then
        -- negative wrap
        i = #version_states
      else
        -- decrement
        i = i - 1
      end

      button_animation:set_state(version_states[i])
    end

    -- arrow animations
    if player:input_has(Input.Held.Left) then
      arrow_animation:set_state("RIGHT_ACTIVE")
    else
      arrow_animation:set_state("RIGHT")
    end

    arrow_animation:apply(left_arrow)

    if player:input_has(Input.Held.Right) then
      arrow_animation:set_state("RIGHT_ACTIVE")
    else
      arrow_animation:set_state("RIGHT")
    end

    arrow_animation:apply(right_arrow)


    if player:input_has(Input.Pressed.Confirm) then
      -- reset use_func
      button.use_func = nil

      -- clean up
      player:set_card_selection_blocked(false)
      button_sprite:remove_node(left_arrow)
      button_sprite:remove_node(right_arrow)
      reset_component:eject()
      focused_component:eject()

      -- play audio
      Resources.play_audio(Resources.game_folder() .. "resources/sfx/cursor_select.ogg")

      -- callback
      on_complete(version_states[i])
    elseif player:input_has(Input.Pressed.Cancel) then
      -- play audio
      Resources.play_audio(Resources.game_folder() .. "resources/sfx/cursor_cancel.ogg")

      -- reset
      reset()
    end
  end

  button.use_func = function()
    player:set_card_selection_blocked(true)
    left_arrow:set_visible(true)
    right_arrow:set_visible(true)
    focused = true
    just_focused = true
    return true
  end
end
