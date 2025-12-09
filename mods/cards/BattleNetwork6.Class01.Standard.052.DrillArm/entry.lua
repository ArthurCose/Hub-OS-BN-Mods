---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local TEXTURE = bn_assets.load_texture("drill_arm.png")
local ANIMATION_PATH = bn_assets.fetch_animation_path("drill_arm.animation")

local AUDIO = bn_assets.load_audio("drillarm1.ogg")

---@param user Entity
---@param hit_props HitProps
---@param spells Entity[]
local function attack(user, hit_props, spells)
  local facing = user:facing()
  local tile = user:get_tile(facing, 1)

  if not tile then
    return
  end

  local spell = Spell.new(user:team())
  spell:set_facing(facing)
  spell:set_hit_props(hit_props)

  spell.on_collision_func = function(_, other)
    local hit_effect = bn_assets.HitParticle.new("BREAK", math.random(-12, 12), math.random(-4, 4))

    Field.spawn(hit_effect, other:current_tile())
  end

  spell.on_update_func = function(self)
    self:attack_tiles(
      {
        self:current_tile(),
        self:get_tile(facing, 1)
      }
    )
  end

  table.insert(spells, spell)

  Field.spawn(spell, tile)
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  local action = Action.new(user, "CHARACTER_SHOOT")

  action:override_animation_frames(
    {
      { 1, 10 },
      { 1, 1 },
      { 1, 10 },
      { 1, 1 },
      { 1, 11 },
      { 1, 1 },
      { 1, 20 }
    }
  )

  local spells = {}

  action:set_lockout(ActionLockout.new_animation())

  action.on_execute_func = function()
    local attachment = action:create_attachment("BUSTER")
    local sprite = attachment:sprite()
    local animation = attachment:animation()

    sprite:set_texture(TEXTURE)
    animation:load(ANIMATION_PATH)

    animation:set_state("DEFAULT")
    animation:set_playback(Playback.Once)

    local timer = 0
    local can_attack = true

    local drag = Drag.new(user:facing(), 1)
    local hit_props = HitProps.from_card(props, user:context(), drag)

    action.on_update_func = function()
      if #spells == 3 then can_attack = false end

      if timer % 11 == 0 and can_attack == true then
        attack(user, hit_props, spells)
      end

      timer = timer + 1
    end

    Resources.play_audio(AUDIO)
  end

  action.on_action_end_func = function()
    for i = 1, #spells, 1 do
      spells[i]:erase()
    end
  end

  return action
end
