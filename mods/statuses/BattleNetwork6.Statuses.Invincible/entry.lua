local lime = Color.new(0, 255, 0)
local black = Color.new(0, 0, 0)

---@param status Status
function status_init(status)
  local entity = status:owner()

  -- handle defense
  local defense_rule = DefenseRule.new(DefensePriority.Body, DefenseOrder.Always)
  defense_rule.can_block_func = function(judge)
    judge:block_damage()
  end
  defense_rule.on_replace_func = function()
    status:set_remaining_time(0)
  end
  entity:add_defense_rule(defense_rule)

  -- handle color
  local component = entity:create_component(Lifetime.Battle)
  local sprite = entity:sprite()
  local time = 16

  component.on_update_func = function()
    local progress = math.abs(time % 32 - 16) / 16
    time = time + 1

    sprite:set_color_mode(ColorMode.Additive)
    sprite:set_color(Color.mix(lime, black, progress))
  end

  -- cleanup
  status.on_delete_func = function()
    entity:remove_defense_rule(defense_rule)
    component:eject()
  end
end
