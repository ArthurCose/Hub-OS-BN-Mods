---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local SFX = bn_assets.load_audio("bugfix.ogg")

local timing = {
  3, -- plain
  3, -- white
  1, -- plain (alternating...)
  1,
  1,
  1,
  2,
  1,
  2,
  1,
  3,
  1,
  4,
  1,
  5,
  1,
  7,
  1,
  9,
  1,
  11,
  1,
  14,
  1,
  18,
  1,
  23,
  1,
  31
}

local WHITE = Color.new(255, 255, 255, 255)

---@param user Entity
function card_init(user)
  local action = Action.new(user)
  action:set_lockout(ActionLockout.new_sequence())

  local i = 1
  local color_duration = timing[i]
  local use_white = false

  local step = action:create_step()

  step.on_update_func = function()
    if use_white then
      user:set_color(WHITE)
    end

    color_duration = color_duration - 1

    if color_duration ~= 0 then
      return
    end

    i = i + 1
    color_duration = timing[i]
    use_white = not use_white

    if color_duration and use_white then
      -- just switched to white, play the audio
      Resources.play_audio(SFX)
    end

    if not color_duration then
      -- completed animation!
      step:complete_step()

      -- uninstall bugs
      for _, augment in ipairs(user:augments()) do
        if augment:has_tag("BUG") then
          user:boost_augment(augment:id(), -augment:level())
        end
      end
    end
  end

  return action
end
