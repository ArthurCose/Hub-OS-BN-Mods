function card_mutate(user, card_index)
  if Player.from(user) == nil then return end
  user:boost_augment("BattleNetwork6.Bugs.WarpStep", 1)
end

---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local AUDIO = bn_assets.load_audio("bug_power.ogg")

local can_use = false

local function create_boost_aux(user, card)
  local health = user:health()
  local max_health = user:max_health()
  local boost
  if health == 1 then
    boost = 1.0
  else
    boost = 1 - (health / max_health)
  end


  print(boost)

  local aux = AuxProp.new()
      :require_card_damage(Compare.EQ, card.damage)
      :increase_card_multiplier(boost)

  user:add_aux_prop(aux)
end

function card_mutate(player, index)
  local card = player:field_card(index + 1)

  if not card then return end
  if card.can_boost == false then return end
  if card.attack == 0 then return end

  can_use = true
end

function card_init(actor, props)
  if can_use == false then return Action.new(actor) end

  local action = Action.new(actor);

  local step = action:create_step()

  action:set_lockout(ActionLockout.new_sequence())

  action.on_execute_func = function(self, user)
    local lime = Color.new(0, 255, 0)
    local black = Color.new(0, 0, 0)
    local comp = user:create_component(Lifetime.Battle)

    local time = 16
    local sprite = user:sprite()
    Resources.play_audio(AUDIO, AudioBehavior.NoOverlap)

    comp.on_update_func = function(self)
      if time == 32 then
        local card = user:field_card(1)
        create_boost_aux(user, card)
        step:complete_step()
        action:end_action()
        self:eject()

        return
      end

      local progress = math.abs(time % 32 - 16) / 16
      time = time + 1

      sprite:set_color_mode(ColorMode.Additive)
      sprite:set_color(Color.mix(lime, black, progress))
    end
  end

  return action;
end
