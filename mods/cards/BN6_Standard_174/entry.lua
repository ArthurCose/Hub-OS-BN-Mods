---@type BattleNetwork.Assets
local bn_assets = require('BattleNetwork.Assets')
local TEXTURE = Resources.load_texture("pointer.png")
local ANIMATION_PATH = "pointer.animation"
local indicate = bn_assets.load_audio("indicate.ogg")

local animation = Animation.new(ANIMATION_PATH)

---@param user Entity
function card_init(user)
  local action = Action.new(user)
  action:set_lockout(ActionLockout.new_sequence())

  local hud_sprite

  action.on_execute_func = function()
    local old_max_time = TurnGauge.max_time()
    local new_max_time = 1024
    TurnGauge.set_max_time(new_max_time)

    -- scale time
    TurnGauge.set_time(TurnGauge.time() * new_max_time / old_max_time)

    -- reset animation
    animation:set_state("DEFAULT")
    animation:set_playback(Playback.Loop)

    -- create sprite
    hud_sprite = Hud:create_node()
    hud_sprite:set_texture(TEXTURE)
    hud_sprite:set_offset(120, 12)
    animation:apply(hud_sprite)

    -- create step to update the animation and wait for completion
    local step = action:create_step()

    step.on_update_func = function()
      animation:update()
      animation:apply(hud_sprite)
    end

    local loops = 0
    animation:on_complete(function()
      loops = loops + 1

      if loops == 4 then
        -- complete after four loops
        step:complete_step()
      end

      Resources.play_audio(indicate)
    end)

    Resources.play_audio(indicate)
  end

  action.on_action_end_func = function()
    if hud_sprite then
      Hud:remove_node(hud_sprite)
    end
  end

  return action
end
