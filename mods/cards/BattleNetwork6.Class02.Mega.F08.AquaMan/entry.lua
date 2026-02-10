---@type BattleNetwork6.Libraries.ChipNavi
local ChipNaviLib = require("BattleNetwork6.Libraries.ChipNavi")
---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local APPEAR_SFX = bn_assets.load_audio("appear.ogg")

local CHARGE_SHOT_TEXTURE = bn_assets.load_texture("aqua_hose.png")
local CHARGE_SHOT_ANIM_PATH = bn_assets.fetch_animation_path("aqua_hose.animation")
local BUBBLES_TEXTURE = bn_assets.load_texture("bn4_bubble_impact.png")
local BUBBLES_ANIMATION_PATH = bn_assets.fetch_animation_path("bn4_bubble_impact.animation")
local BUBBLES_SFX = bn_assets.load_audio("bubbler.ogg")
local SHOOT_SFX = bn_assets.load_audio("aqua_hose.ogg")

local HOSE_TEXTURE = bn_assets.load_texture("aqua_stream_hose.png")
local HOSE_ANIM_PATH = bn_assets.fetch_animation_path("aqua_stream_hose.animation")
local STREAM_TEXTURE = bn_assets.load_texture("aqua_stream.png")
local STREAM_ANIM_PATH = bn_assets.fetch_animation_path("aqua_stream.animation")
local STREAM_SFX = bn_assets.load_audio("aqua_stream.ogg")

local NAVI_TEXTURE = bn_assets.load_texture("navi_aquaman.png")
local NAVI_ANIM_PATH = bn_assets.fetch_animation_path("navi_aquaman.animation")
local NAVI_SHADOW_TEXTURE = bn_assets.load_texture("navi_aquaman_shadow.png")
local NAVI_SHADOW_ANIM_PATH = bn_assets.fetch_animation_path("navi_aquaman_shadow.animation")

---Adapted from AquaMan's CS
---@param navi Entity
---@param action Action
---@param hit_props HitProps
local function add_charge_shot_steps(navi, action, hit_props)
  local AQUA_HOSE_FRAMES = { { 1, 8 }, { 2, 4 }, { 3, 4 }, { 4, 24 } }

  local step = action:create_step()

  step.on_update_func = function()
    step.on_update_func = nil

    local navi_action = Action.new(navi, "CHARACTER_SHOOT")
    navi_action:override_animation_frames(AQUA_HOSE_FRAMES)

    navi_action:set_lockout(ActionLockout.new_animation())

    local buster, buster_anim

    navi_action.on_execute_func = function()
      buster = navi_action:create_attachment("BUSTER")
      local buster_sprite = buster:sprite()
      buster_sprite:set_texture(navi:texture())
      buster_sprite:set_layer(-1)
      buster_sprite:use_root_shader()

      buster_anim = buster:animation()
      buster_anim:copy_from(navi:animation())
      buster_anim:set_state("BUSTER", AQUA_HOSE_FRAMES)
    end

    navi_action:on_anim_frame(2, function()
      Resources.play_audio(SHOOT_SFX)

      local flare = buster:create_attachment("ENDPOINT")
      local flare_sprite = flare:sprite()
      flare_sprite:set_texture(CHARGE_SHOT_TEXTURE)
      flare_sprite:set_layer(-2)
      flare_sprite:use_root_shader()

      local flare_anim = flare:animation()
      flare_anim:load(CHARGE_SHOT_ANIM_PATH)
      flare_anim:set_state("ATTACHMENT")

      -- immediately spawn the attack
      local spell = Spell.new(navi:team())
      spell:set_facing(navi:facing())
      spell:set_texture(CHARGE_SHOT_TEXTURE)

      local spell_anim = spell:animation()
      spell_anim:load(CHARGE_SHOT_ANIM_PATH)
      spell_anim:set_state("BLOB")

      local direction = navi:facing()

      local total_frames = 16

      local buster_point = navi:animation():relative_point("BUSTER")
      local flare_point = buster_anim:relative_point("ENDPOINT")

      local x = buster_point.x + flare_point.x + spell:sprite():origin().x
      local y = buster_point.y + flare_point.y
      local vel_x = (Tile:width() * 2 - x) / total_frames
      local vel_y = -y / total_frames

      if direction == Direction.Left then
        x = -x
        vel_x = -vel_x
      end

      spell:set_offset(math.floor(x), math.floor(y))

      local function spawn_bubbles(tile, cracks)
        if not tile then
          return
        end

        local bubbles = Spell.new(spell:team())
        bubbles:set_facing(spell:facing())
        bubbles:set_hit_props(hit_props)
        bubbles:set_texture(BUBBLES_TEXTURE)

        bubbles.on_spawn_func = function()
          bubbles:attack_tile()
        end

        local bubbles_anim = bubbles:animation()
        bubbles_anim:load(BUBBLES_ANIMATION_PATH)
        bubbles_anim:set_state("BN6")
        bubbles_anim:on_complete(function()
          bubbles:delete()
        end)

        if cracks then
          bubbles.on_delete_func = function()
            if tile:state() == TileState.Cracked then
              tile:set_state(TileState.Broken)
            else
              tile:set_state(TileState.Cracked)
            end

            bubbles:erase()
          end
        end

        Field.spawn(bubbles, tile)
      end

      spell.on_update_func = function()
        spell:set_offset(math.floor(x), math.floor(y))
        x = x + vel_x
        y = y + vel_y

        if y < 0 then
          return
        end

        spell:delete()

        Resources.play_audio(BUBBLES_SFX)

        local first_tile = spell:get_tile(spell:facing(), 2)

        if not first_tile then
          return
        end

        if not first_tile:is_walkable() then
          local particle = bn_assets.MobMove.new("SMALL_END")
          Field.spawn(particle, first_tile)

          -- fallback test, spawn bubbles for direct hits
          local hit_test = Spell.new(spell:team())
          hit_test:attack_tile(first_tile)
          hit_test.on_spawn_func = function()
            hit_test:delete()
          end
          hit_test.on_collision_func = function()
            spawn_bubbles(first_tile, true)
            spawn_bubbles(spell:get_tile(spell:facing(), 3))
            particle:delete()
          end
          Field.spawn(hit_test, first_tile)
          return
        end

        spawn_bubbles(first_tile, true)
        spawn_bubbles(spell:get_tile(spell:facing(), 3))
      end

      Field.spawn(spell, navi:current_tile())
    end)

    navi_action.on_action_end_func = function()
      step:complete_step()
    end

    navi:queue_action(navi_action)
  end
end

---@param navi Entity
---@param action Action
---@param hit_props HitProps
local function add_stream_steps(navi, action, hit_props)
  local animation = navi:animation()
  ---@type Entity, Animation
  local hose, hose_animation
  ---@type Entity[]
  local stream_artifacts = {}
  ---@type Tile[]
  local tiles = {}

  local start_step = action:create_step()
  start_step.on_update_func = function()
    start_step.on_update_func = nil

    -- create hose
    hose = Spell.new()
    hose:set_hit_props(hit_props)
    hose:set_facing(navi:facing())
    hose:set_texture(HOSE_TEXTURE)
    hose:set_layer(-1)

    hose.on_collision_func = function(_, other)
      local tile = other:current_tile()
      local offset = other:movement_offset()

      local particle = bn_assets.HitParticle.new("AQUA")
      particle:set_offset(
        offset.x + math.random(-16, 16),
        offset.y - other:height() // 2 + math.random(-16, 16)
      )

      Field.spawn(particle, tile)
    end

    hose.on_spawn_func = function()
      -- animate navi
      animation:set_state("AQUA_STREAM_START")
    end

    hose_animation = hose:animation()
    hose_animation:load(HOSE_ANIM_PATH)
    hose_animation:set_state("START")
    hose_animation:on_complete(function()
      animation:set_state("AQUA_STREAM_IDLE")
      hose_animation:set_state("IDLE")
      start_step:complete_step()
    end)

    Field.spawn(hose, navi:current_tile())
  end

  ChipNaviLib.create_delay_step(action, 30)

  local pump_step = action:create_step()
  pump_step.on_update_func = function()
    pump_step.on_update_func = nil

    hose_animation:set_state("PUMP")
    hose_animation:on_complete(function()
      Resources.play_audio(STREAM_SFX)

      hose_animation:set_state("LOOP")
      hose_animation:set_playback(Playback.Loop)
      animation:set_state("AQUA_STREAM_LOOP")
      animation:set_playback(Playback.Loop)

      -- resolve target dist
      local navi_x = navi:current_tile():x()
      local target_x = Field.width() - 2

      if navi:facing() == Direction.Left then
        target_x = 1
      end

      local target_dist = math.abs(target_x - navi_x)

      Field.find_characters(function(entity)
        if not entity:hittable() then
          return false
        end

        local x = entity:current_tile():x()

        if navi:facing() == Direction.Left then
          if x >= navi_x then
            return false
          end
        elseif x <= navi_x then
          return false
        end

        target_dist = math.min(target_dist, math.abs(navi_x - x))

        return false
      end)

      target_dist = math.max(target_dist, 1)

      -- build artifacts

      ---@param state string
      ---@param tile Tile?
      local function create_artifact(state, tile)
        if not tile then
          return nil
        end

        local artifact = Artifact.new()
        artifact:set_layer(-2)
        artifact:set_texture(STREAM_TEXTURE)
        artifact:set_facing(navi:facing())

        local spell_animation = artifact:animation()
        spell_animation:load(STREAM_ANIM_PATH)
        spell_animation:set_state(state)
        spell_animation:set_playback(Playback.Loop)

        Field.spawn(artifact, tile)

        stream_artifacts[#stream_artifacts + 1] = artifact
        tiles[#tiles + 1] = tile

        return artifact
      end

      create_artifact("START", navi:current_tile())

      for dist = 1, target_dist - 1 do
        create_artifact("MIDDLE", navi:get_tile(navi:facing(), dist))
      end

      local end_spell = create_artifact("END", navi:get_tile(navi:facing(), target_dist))

      if end_spell then
        end_spell:set_layer(-3)

        -- no gaps since nil values won't affect the length of the array
        tiles[#tiles + 1] = end_spell:get_tile(Direction.Up, 1)
        tiles[#tiles + 1] = end_spell:get_tile(Direction.Down, 1)
      end

      pump_step:complete_step()
    end)
  end

  local attack_step = action:create_step()
  local attack_time = 0
  local hits = 0
  attack_step.on_update_func = function()
    attack_time = attack_time + 1

    -- highlight tiles
    for i = 1, #tiles do
      local tile = tiles[i]

      if i ~= 1 then
        tile:set_highlight(Highlight.Solid)
      end
    end

    if attack_time % 30 ~= 1 then
      return
    end

    if hits == 3 then
      -- we've hit enough times
      attack_step:complete_step()
      return
    end

    hits = hits + 1

    -- attack tiles
    for _, tile in ipairs(tiles) do
      hose:attack_tile(tile)
    end
  end

  local cleanup_step = action:create_step()
  cleanup_step.on_update_func = function()
    navi:set_idle()
    hose:delete()

    for _, entity in ipairs(stream_artifacts) do
      entity:delete()
    end

    cleanup_step:complete_step()
  end
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  local action = Action.new(user)
  action:set_lockout(ActionLockout.new_sequence())

  local previously_visible = user:sprite():visible()
  ---@type Entity
  local navi

  local hit_props = HitProps.from_card(props)

  action.on_execute_func = function()
    previously_visible = user:sprite():visible()

    -- spawn navi
    navi = Artifact.new(user:team())
    navi:set_facing(user:facing())
    navi:set_texture(NAVI_TEXTURE)
    navi:set_shadow(NAVI_SHADOW_TEXTURE, NAVI_SHADOW_ANIM_PATH)
    navi:hide()

    local navi_animation = navi:animation()
    navi_animation:load(NAVI_ANIM_PATH)
    navi_animation:set_state("CHARACTER_IDLE")
    navi_animation:set_playback(Playback.Loop)

    navi.on_idle_func = function()
      navi_animation:set_state("CHARACTER_IDLE")
      navi_animation:set_playback(Playback.Loop)
    end

    local tile = user:current_tile()
    Field.spawn(navi, tile)

    -- build steps
    ChipNaviLib.create_exit_step(action, user)
    ChipNaviLib.create_delay_step(action, 29)

    local appear_sfx_step = action:create_step()
    appear_sfx_step.on_update_func = function()
      Resources.play_audio(APPEAR_SFX)
      appear_sfx_step:complete_step()
    end

    ChipNaviLib.create_enter_step(action, navi)

    if tile:is_walkable() then
      ChipNaviLib.create_idle_step(action, navi)

      local x = tile:x()

      if user:facing() == Direction.Left then
        x = Field.width() - x - 1
      end

      if x <= 2 then
        add_stream_steps(navi, action, hit_props)
      else
        add_charge_shot_steps(navi, action, hit_props)
      end
    end

    ChipNaviLib.create_exit_step(action, navi)
    ChipNaviLib.create_enter_step(action, user)
  end

  action.on_action_end_func = function()
    if previously_visible then
      user:reveal()
    else
      user:hide()
    end

    if navi and not navi:deleted() then
      navi:erase()
    end
  end

  return action
end
