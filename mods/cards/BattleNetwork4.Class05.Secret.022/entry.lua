---@type BattleNetwork6.Libraries.ChipNavi
local ChipNaviLib = require("BattleNetwork6.Libraries.ChipNavi")
local bn_assets = require("BattleNetwork.Assets")

local NAVI_TEXTURE = bn_assets.load_texture("NumbrBl.png")
local NAVI_ANIM_PATH = bn_assets.fetch_animation_path("NumbrBl.animation")

local APPEAR_SFX = bn_assets.load_audio("appear.ogg")
local ATTACK_SFX = bn_assets.load_audio("lifeaura.ogg")
local IMPACT_SFX = bn_assets.load_audio("hurt.ogg")

local ATTACK_COUNT = 3  -- BALL攻撃の回数

---@param user Entity
---@param index number
function card_mutate(user, index)
  -- No mutation needed
end

---@param user Entity
function card_dynamic_damage(user)
  return user:health() % 100
end

-- BALLの攻撃用Spellを作成
local function create_ball_spell(team, direction, hit_props)
  local spell = Spell.new(team)
  spell:set_facing(direction)
  
  spell:set_hit_props(hit_props)
  spell:set_texture(NAVI_TEXTURE)
  
  local animation = spell:animation()
  animation:load(NAVI_ANIM_PATH)
  animation:set_state("BALL")
  animation:set_playback(Playback.Once)
  
  -- 攻撃力の表示（数字）を追加
  local damage = hit_props.damage
  local tens_digit = math.floor(damage / 10) % 10  -- 十の位
  local ones_digit = damage % 10  -- 一の位
  
  -- 向きに応じてオフセットを調整（位置関係を反転させない）
  local tens_offset_x, ones_offset_x
  if direction == Direction.Right then
    tens_offset_x = -5  -- 十の位は左
    ones_offset_x = 3   -- 一の位は右
  else
    tens_offset_x = 5   -- 左向きの場合は符号を反転
    ones_offset_x = -3
  end
  
  -- 十の位の数字
  local tens_sprite = spell:create_node()
  tens_sprite:set_texture(NAVI_TEXTURE)
  tens_sprite:set_layer(-1)
  tens_sprite:set_offset(tens_offset_x, 0)
  tens_sprite:set_never_flip(true)  -- 反転しない
  tens_sprite:hide()  -- 最初は非表示
  
  local tens_animation = Animation.new(NAVI_ANIM_PATH)
  tens_animation:set_state(tostring(tens_digit))
  tens_animation:apply(tens_sprite)
  
  -- 一の位の数字
  local ones_sprite = spell:create_node()
  ones_sprite:set_texture(NAVI_TEXTURE)
  ones_sprite:set_layer(-1)
  ones_sprite:set_offset(ones_offset_x, 0)
  ones_sprite:set_never_flip(true)  -- 反転しない
  ones_sprite:hide()  -- 最初は非表示
  
  local ones_animation = Animation.new(NAVI_ANIM_PATH)
  ones_animation:set_state(tostring(ones_digit))
  ones_animation:apply(ones_sprite)
  
  local wait_frames = 0
  local started_moving = false
  local frame_count = 0  -- フレームカウント
  
  spell.on_update_func = function(self)
    frame_count = frame_count + 1
    
    -- 13フレーム目に数字を表示
    if frame_count == 13 then
      tens_sprite:reveal()
      ones_sprite:reveal()
    end
    
    local tile = self:current_tile()
    if tile then
      tile:attack_entities(self)
    end
    
    -- 20フレーム待機してから移動開始
    if not started_moving then
      wait_frames = wait_frames + 1
      if wait_frames >= 20 then
        started_moving = true
        local next_tile = self:get_tile(direction, 1)
        if next_tile and not next_tile:is_edge() then
          self:slide(next_tile, 15)
        else
          -- エッジタイルなので爆発なしで消す
          self:erase()
        end
      end
      return
    end
    
    -- 移動中
    if self:is_moving() then
      return
    end
    
    -- 移動完了後、次のタイルへ
    local next_tile = self:get_tile(direction, 1)
    if next_tile and not next_tile:is_edge() then
      self:slide(next_tile, 15)
    else
      -- エッジタイルを超えたので爆発なしで消す
      self:erase()
    end
  end
  
  spell.on_collision_func = function(self)
    -- 衝突したので爆発
    local explosion = Explosion.new(team)
    Field.spawn(explosion, self:current_tile())
    Resources.play_audio(IMPACT_SFX)
    self:erase()
  end
  
  return spell
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  local action = Action.new(user)
  action:set_lockout(ActionLockout.new_sequence())

  local numbrbl
  local ball_spells = {}
  local previously_visible
  local fixed_damage  -- カード使用時に確定したダメージ

  action.on_execute_func = function()
    previously_visible = user:sprite():visible()
    
    -- カード使用時点でダメージを確定
    fixed_damage = user:health() % 100

    -- NumbrBlキャラクター生成
    numbrbl = Spell.new(user:team())
    numbrbl:set_facing(user:facing())
    numbrbl:hide()
    numbrbl:set_texture(NAVI_TEXTURE)

    local numbrbl_animation = numbrbl:animation()
    numbrbl_animation:load(NAVI_ANIM_PATH)
    numbrbl_animation:set_state("DEFAULT")
    numbrbl_animation:set_playback(Playback.Loop)

    numbrbl:set_height(numbrbl:sprite():origin().y)

    Field.spawn(numbrbl, user:current_tile())

    -- 1. プレイヤー退場
    local swap_in_step = action:create_step()
    swap_in_step.on_update_func = function()
      swap_in_step.on_update_func = nil

      ChipNaviLib.exit(user, function()
        ChipNaviLib.delay_for_swap(function()
          Resources.play_audio(APPEAR_SFX)
          swap_in_step:complete_step()
        end)
      end)
    end

    -- 2. CHARACTER_MOVE_IN アニメーション再生
    local move_in_step = action:create_step()
    move_in_step.on_update_func = function()
      move_in_step.on_update_func = nil
      
      numbrbl:reveal()
      numbrbl_animation:set_state("CHARACTER_MOVE_IN")
      numbrbl_animation:set_playback(Playback.Once)
      
      numbrbl_animation:on_complete(function()
        move_in_step:complete_step()
      end)
    end

    -- 3. DEFAULT状態で30フレーム待機
    local default_wait_step = action:create_step()
    local default_wait_frames = 0
    default_wait_step.on_update_func = function()
      if default_wait_frames == 0 then
        numbrbl_animation:set_state("DEFAULT")
        numbrbl_animation:set_playback(Playback.Loop)
      end
      
      default_wait_frames = default_wait_frames + 1
      
      if default_wait_frames >= 30 then
        default_wait_step:complete_step()
      end
    end

    -- 4. BALL生成（3回、20フレーム間隔）
    for i = 1, ATTACK_COUNT do
      -- CHARACTER_ATTACK アニメーション
      local attack_anim_step = action:create_step()
      attack_anim_step.on_update_func = function()
        attack_anim_step.on_update_func = nil
        
        numbrbl_animation:set_state("CHARACTER_ATTACK")
        numbrbl_animation:set_playback(Playback.Once)
        Resources.play_audio(ATTACK_SFX)
        
        -- アニメーション途中でBALL生成
        numbrbl_animation:on_frame(3, function()
          -- 確定したダメージでHitPropsを作成
          local hit_props = HitProps.from_card(props, user:context())
          hit_props.damage = fixed_damage + (props.boosted_damage or 0)
          
          -- 目の前のタイルにBALL生成
          local front_tile = numbrbl:get_tile(numbrbl:facing(), 1)
          if front_tile then
            local ball = create_ball_spell(user:team(), numbrbl:facing(), hit_props)
            Field.spawn(ball, front_tile)
            table.insert(ball_spells, ball)
          end
        end, true)
        
        numbrbl_animation:on_complete(function()
          attack_anim_step:complete_step()
        end)
      end
      
      -- 攻撃後、DEFAULTに戻す
      local return_to_default_step = action:create_step()
      return_to_default_step.on_update_func = function()
        return_to_default_step.on_update_func = nil
        
        numbrbl_animation:set_state("DEFAULT")
        numbrbl_animation:set_playback(Playback.Loop)
        return_to_default_step:complete_step()
      end
      
      -- 最後のBALL以外は10フレーム待機
      if i < ATTACK_COUNT then
        ChipNaviLib.create_delay_step(action, 10)
      end
    end

    -- 5. すべてのBALLが消えるまで待機
    local wait_for_balls_step = action:create_step()
    wait_for_balls_step.on_update_func = function()
      local all_deleted = true
      
      for _, ball in ipairs(ball_spells) do
        if not ball:deleted() then
          all_deleted = false
          break
        end
      end
      
      if all_deleted then
        wait_for_balls_step:complete_step()
      end
    end

    -- 6. 30フレーム待機
    ChipNaviLib.create_delay_step(action, 30)

    -- 7. CHARACTER_MOVE_OUT アニメーション再生
    local move_out_step = action:create_step()
    move_out_step.on_update_func = function()
      move_out_step.on_update_func = nil
      
      numbrbl_animation:set_state("CHARACTER_MOVE_OUT")
      numbrbl_animation:set_playback(Playback.Once)
      
      numbrbl_animation:on_complete(function()
        move_out_step:complete_step()
      end)
    end

    -- 8. NumbrBl削除
    local delete_numbrbl_step = action:create_step()
    delete_numbrbl_step.on_update_func = function()
      delete_numbrbl_step.on_update_func = nil
      
      if numbrbl and not numbrbl:deleted() then
        numbrbl:erase()
        numbrbl = nil
      end
      
      delete_numbrbl_step:complete_step()
    end

    -- 9. 20フレーム待機
    ChipNaviLib.create_delay_step(action, 20)

    -- 10. プレイヤー復帰
    ChipNaviLib.create_enter_step(action, user)

    -- 11. 30フレーム待機
    ChipNaviLib.create_delay_step(action, 30)

  end

  action.on_action_end_func = function()
    if previously_visible ~= nil then
      if previously_visible then
        user:reveal()
      else
        user:hide()
      end
    end

    if numbrbl and not numbrbl:deleted() then
      numbrbl:delete()
    end
    
    for _, ball in ipairs(ball_spells) do
      if not ball:deleted() then
        ball:delete()
      end
    end
  end

  return action
end
