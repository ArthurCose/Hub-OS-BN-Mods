---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
local bn_assets_ring = require("BattleChipChallenge.Libraries.Ring")

local TEXTURE = bn_assets_ring.load_texture("trumpy.png")
local ANIMATION_PATH = bn_assets_ring.fetch_animation_path("trumpy.animation")
local APPEAR_SFX = bn_assets.load_audio("appear.ogg")
local MUSIC_SFX = bn_assets_ring.load_audio("panic.ogg")
local MUSIC_INTERVAL = 300
local IDLE_DURATION = 60 -- acts as 60f cooldown, warn animation is 30f
local PLAY_DURATION = 240
local BUG_ID = "BattleChipChallenge.Ring.Bug.RandomStep"
local BUG_BOOST_AMOUNT = 2
local BLINK_INTERVAL = 2 -- ピンク色点滅の間隔（フレーム）
local PINK_COLOR = Color.new(255, 100, 200) -- ピンク色
local NORMAL_COLOR = Color.new(0, 0, 0) -- 通常色（加算モードで透明）

-- 影響を受けた敵を追跡するテーブル（IDとコンポーネントのマップ）
local affected_enemies = {}

local function apply_bug(team)
  -- 相手チームの全キャラクターを見つける
  Field.find_characters(function(character)
    -- 同じチームの場合、または削除されている場合はスキップ
    if character:team() == team or character:deleted() then
      return false
    end

    local char_id = character:id()

    -- バグをブースト（失敗する可能性があるのでpcallで保護）
    local success, error_msg = pcall(function()
      character:boost_augment(BUG_ID, BUG_BOOST_AMOUNT)
    end)
    
    -- boost_augmentが失敗した場合はこのキャラクターをスキップ
    if not success then
      return false
    end
    
    -- ピンク色点滅のコンポーネントを作成
    local component = character:create_component(Lifetime.Battle)
    local blink_time = 0
    
    component.on_update_func = function()
      if character:deleted() then
        component:eject()
        return
      end
      
      blink_time = blink_time + 1
      
      -- Flash状態でない場合のみ色を変更
      if character:remaining_status_time(Hit.Flash) <= 0 then
        local sprite = character:sprite()
        sprite:set_color_mode(ColorMode.Add)
        
        -- 点滅効果
        if (blink_time // BLINK_INTERVAL) % 2 == 0 then
          sprite:set_color(PINK_COLOR)
        else
          sprite:set_color(NORMAL_COLOR)
        end
      end
    end
    
    -- 影響を受けた敵を追跡
    affected_enemies[char_id] = component

    return false
  end)
end

local function remove_bug()
  -- 影響を受けた敵全員からバグと点滅効果を削除
  for enemy_id, component in pairs(affected_enemies) do
    Field.find_characters(function(character)
      if character:id() == enemy_id and not character:deleted() then
        -- バグを削除（失敗する可能性があるのでpcallで保護）
        pcall(function()
          character:boost_augment(BUG_ID, -BUG_BOOST_AMOUNT)
        end)
        
        -- 色を元に戻す
        local sprite = character:sprite()
        sprite:set_color_mode(ColorMode.Add)
        sprite:set_color(NORMAL_COLOR)
        
        -- コンポーネントを削除
        if component then
          component:eject()
        end
      end
      return false
    end)
  end
  -- テーブルをクリア
  affected_enemies = {}
end

---@param user Entity
local function create_trumpy(user)
  local team = user:team()

  local trumpy = Obstacle.new(team)
  trumpy:set_owner(user)
  trumpy:set_facing(user:facing())
  trumpy:set_texture(TEXTURE)
  trumpy:set_health(100)

  trumpy:add_aux_prop(StandardEnemyAux.new())

  local animation = trumpy:animation()
  animation:load(ANIMATION_PATH)
  animation:set_state("IDLE")

  local bugs_applied = false

  trumpy.on_delete_func = function()
    -- 演奏中にバグが適用されていた場合、削除
    if bugs_applied then
      remove_bug()
    end
    trumpy:erase()
    Field.spawn(Explosion.new(), trumpy:current_tile())
  end

  trumpy.can_move_to_func = function(tile)
    return tile:is_walkable() and tile:team() == team and not tile:is_reserved()
  end

  local time = 0
  local state_remaining_time = 0
  local music_time = 0

  trumpy.on_update_func = function()
    if TurnGauge.frozen() then
      return
    end

    time = time + 1
    music_time = music_time + 1

    if time > 2400 then
      trumpy:delete()
      return
    end

    if state_remaining_time > 0 then
      state_remaining_time = state_remaining_time - 1
    end

    local state = animation:state()

    if state == "IDLE" then
      if state_remaining_time == 0 then
        animation:set_state("WARN")
        animation:on_complete(function()
          animation:set_state("PLAY")
          animation:set_playback(Playback.Loop)

          state_remaining_time = PLAY_DURATION
          music_time = 0
          Resources.play_audio(MUSIC_SFX, AudioBehavior.NoOverlap)
          
          -- 演奏開始時にバグを適用
          if not bugs_applied then
            apply_bug(team)
            bugs_applied = true
          end
        end)
      end
    elseif state == "PLAY" then
      if state_remaining_time > 0 then
        -- 演奏中は何もしない（バグは既に適用済み）
      else
        -- 演奏終了時にバグを削除
        if bugs_applied then
          remove_bug()
          bugs_applied = false
        end
        animation:set_state("IDLE")
        state_remaining_time = IDLE_DURATION
      end

      if music_time % MUSIC_INTERVAL == 0 then
        Resources.play_audio(MUSIC_SFX, AudioBehavior.NoOverlap)
      end
    end
  end

  return trumpy
end

---@param user Entity
function card_init(user)
  local action = Action.new(user)

  action.on_execute_func = function()
    local tile = user:get_tile(user:facing(), 1)

    if tile and not tile:is_reserved() and tile:is_walkable() then
      Field.spawn(create_trumpy(user), tile)
      Resources.play_audio(APPEAR_SFX)
    end
  end

  return action
end
