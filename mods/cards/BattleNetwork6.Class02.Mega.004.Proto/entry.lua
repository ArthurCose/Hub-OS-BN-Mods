---@type BattleNetwork6.Libraries.ChipNavi
local ChipNaviLib = require("BattleNetwork6.Libraries.ChipNavi")
local bn_assets = require("BattleNetwork.Assets")

local NAVI_TEXTURE = Resources.load_texture("proto.png")
local NAVI_ANIM_PATH = (_folder_path .. "proto.animation")

local APPEAR_SFX = bn_assets.load_audio("appear.ogg")

---@param user Entity
function card_mutate(user, index)
  local card = user:field_card(index)
  local target_recover = card.damage * 3

  if target_recover ~= card.recover then
    card.recover = target_recover
    user:set_field_card(index, card)
  end
end

---@param user Entity
---@param props CardProperties
function card_init(user, props)
  local action = Action.new(user)
  action:set_lockout(ActionLockout.new_sequence())

  local navi
  local previously_visible

  action.on_execute_func = function()
    previously_visible = user:sprite():visible()

    navi = Spell.new(user:team())
    navi:set_facing(user:facing())
    navi:set_hit_props(HitProps.from_card(props, user:context()))
    navi:hide()
    navi:set_texture(NAVI_TEXTURE)

    local navi_animation = navi:animation()
    navi_animation:load(NAVI_ANIM_PATH)
    navi_animation:set_state("CHARACTER_IDLE")
    navi_animation:set_playback(Playback.Loop)

    navi:set_height(navi:sprite():origin().y)

    Field.spawn(navi, user:current_tile())

    -- must create steps in execute func, so they have access to the navi

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

    local max_flicker_time = 16
    local flicker_time = 0
    local color = Color.new(0, 0, 0)
    local flicker_step = action:create_step()
    flicker_step.on_update_func = function()
      if flicker_time % 2 == 0 then
        local v = (1 - flicker_time / max_flicker_time) * 255
        color.r = v
        color.g = v
        color.b = v
        navi:set_color(color)
        navi:reveal()
      else
        navi:hide()
      end

      flicker_time = flicker_time + 1

      if flicker_time >= max_flicker_time then
        navi:reveal()
        flicker_step:complete_step()
      end
    end

    ChipNaviLib.create_delay_step(action, 20)

    -- 自分より前のすべての敵を見つける
    local targets = {}
    local user_x = user:current_tile():x()
    local all_enemies = Field.find_characters(function(e)
      if e:team() == user:team() then
        return false
      end

      if not e:hittable() then
        return false
      end

      -- 自分より前にいる敵のみ
      local enemy_x = e:current_tile():x()

      if user:facing() == Direction.Right then
        return enemy_x > user_x
      else
        return enemy_x < user_x
      end
    end)

    -- 敵をソート（近い順）
    table.sort(all_enemies, function(a, b)
      local a_x = a:current_tile():x()
      local b_x = b:current_tile():x()

      if user:facing() == Direction.Right then
        return a_x < b_x
      else
        return a_x > b_x
      end
    end)

    targets = all_enemies

    if #targets == 0 then
      -- 敵がいない場合、何もしない
      return
    end

    -- 各敵に対してステップを作成
    local reservation_exclusion = { user:id() }
    
    for i, target in ipairs(targets) do
      local moved_successfully = false
      
      -- ターゲットの前に移動
      local exit_to_enemy_step = action:create_step()
      exit_to_enemy_step.on_update_func = function()
        exit_to_enemy_step.on_update_func = nil

        ChipNaviLib.exit(navi, function()
          exit_to_enemy_step:complete_step()
        end)
      end

      local appear_at_enemy_step = action:create_step()
      appear_at_enemy_step.on_update_func = function()
        appear_at_enemy_step:complete_step()

        if target:deleted() then
          return
        end

        local target_tile = target:current_tile()
        if not target_tile then
          return
        end

        local spawn_tile = target_tile:get_tile(user:facing_away(), 1)
        if spawn_tile and not spawn_tile:is_edge() and spawn_tile:is_walkable() and not spawn_tile:is_reserved(reservation_exclusion) then
          spawn_tile:add_entity(navi)
          moved_successfully = true
        elseif target_tile:is_walkable() and not target_tile:is_reserved(reservation_exclusion) then
          -- タイルが無い場合、ターゲットと同じタイルに
          target_tile:add_entity(navi)
          moved_successfully = true
        end
      end

      ChipNaviLib.create_enter_step(action, navi)

      -- WideSwordアクションを直接実装
      local wide_sword_step = action:create_step()
      wide_sword_step.on_update_func = function()
        wide_sword_step.on_update_func = nil

        -- 移動できなかった場合は攻撃をスキップ
        if not moved_successfully then
          wide_sword_step:complete_step()
          return
        end

        if target:deleted() then
          wide_sword_step:complete_step()
          return
        end

        -- WideSwordのアニメーションとロジックを直接実装
        local SLASH_TEXTURE = bn_assets.load_texture("sword_slashes.png")
        local SLASH_ANIM_PATH = bn_assets.fetch_animation_path("sword_slashes.animation")
        local SWORD_AUDIO = bn_assets.load_audio("sword.ogg")

        -- 剣を振るアニメーション
        local navi_anim = navi:animation()
        navi_anim:set_state("CHARACTER_SWING_HILT")
        navi_anim:set_playback(Playback.Once)

        -- スラッシュエフェクトと攻撃判定を作成
        local spells = {}

        -- 攻撃判定用のスペルを3つ作成（中央、上、下）
        local offsets = {
          { x = 1, y = 0 },  -- 中央
          { x = 1, y = -1 }, -- 上
          { x = 1, y = 1 }   -- 下
        }

        for _, offset in ipairs(offsets) do
          local h_tile = navi:get_tile(navi:facing(), offset.x)
          if h_tile then
            local tile = h_tile:get_tile(Direction.Down, offset.y)
            if tile then
              local spell = Spell.new(navi:team())
              spell:set_facing(navi:facing())
              spell:set_hit_props(HitProps.from_card(props, user:context(), Drag.None))

              spell.on_update_func = function(self)
                self:current_tile():attack_entities(self)
              end

              Field.spawn(spell, tile)
              table.insert(spells, spell)
            end
          end
        end

        -- スラッシュエフェクト
        local slash_tile = navi:get_tile(navi:facing(), 1)
        if slash_tile then
          local fx = Spell.new()
          fx:set_facing(navi:facing())
          fx:set_texture(SLASH_TEXTURE)
          local fx_anim = fx:animation()
          fx_anim:load(SLASH_ANIM_PATH)
          fx_anim:set_state("WIDE")
          fx_anim:on_complete(function()
            fx:erase()
            -- スペルを削除
            for _, spell in ipairs(spells) do
              spell:delete()
            end
          end)

          Field.spawn(fx, slash_tile)
        end

        -- 効果音を再生
        Resources.play_audio(SWORD_AUDIO)

        -- アニメーション完了を待つ
        navi_anim:on_complete(function()
          wide_sword_step:complete_step()
        end)
      end

      -- 攻撃後10フレーム待機
      ChipNaviLib.create_delay_step(action, 10)
    end

    -- 全ての攻撃が終わった後、Protoが退場
    local proto_exit_step = action:create_step()
    proto_exit_step.on_update_func = function()
      proto_exit_step.on_update_func = nil

      ChipNaviLib.exit(navi, function()
        proto_exit_step:complete_step()
      end)
    end

    -- Proto退場後20フレーム待機
    ChipNaviLib.create_delay_step(action, 20)

    -- 自分のキャラクターを再出現
    ChipNaviLib.create_enter_step(action, user)

    -- 再出現後40フレーム待機してから終了
    ChipNaviLib.create_delay_step(action, 40)
  end

  action.on_action_end_func = function()
    if previously_visible ~= nil then
      if previously_visible then
        user:reveal()
      else
        user:hide()
      end
    end

    if navi then
      navi:delete()
    end
  end

  return action
end
