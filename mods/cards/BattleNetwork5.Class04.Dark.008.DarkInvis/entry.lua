---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
local SFX = bn_assets.load_audio("bug_power.ogg")

---@param user Entity
function card_init(user)
  local action = Action.new(user)

  action:set_lockout(ActionLockout.new_async(20))

  action.on_execute_func = function()
    if Player.from(user) ~= nil then user:boost_augment("BattleNetwork6.Bugs.BusterBug", 1) end

    local defense_rule = DefenseRule.new(DefensePriority.Body, DefenseOrder.CollisionOnly)

    -- Create a component to handle sprite color and visibility
    local component = user:create_component(Lifetime.Scene)

    -- Create a variable to use as a timer.
    local timer = 180

    -- Store the sprite.
    local sprite = user:sprite()

    -- Store the colors you want.
    local black = Color.new(16, 16, 16, 255)
    local default = sprite:color()
    local transparent = Color.new(default.r, default.g, default.b, 128)

    local color_timer = 16

    -- Use an update function to tick this forward.
    component.on_update_func = function(self)
      if timer == 0 then
        user:remove_defense_rule(defense_rule)
        self:eject()
        return
      end

      sprite:set_color(black)

      -- update timer
      timer = timer - 1

      local progress = math.abs(color_timer % 32 - 16) / 16
      color_timer = color_timer + 1

      sprite:set_color_mode(ColorMode.Additive)
      sprite:set_color(Color.mix(transparent, black, progress))
    end

    defense_rule.on_replace_func = function()
      component:eject()
    end

    defense_rule.defense_func = function(defense, attacker, defender, hit_props)
      if attacker == nil then return end

      defense:block_damage()

      local target = Field.get_entity(hit_props.context.aggressor)
      target:hit(hit_props)
    end

    user:add_defense_rule(defense_rule)

    Resources.play_audio(SFX)
  end

  return action
end
