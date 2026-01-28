local bn_assets = require("BattleNetwork.Assets")

local CURSOR_TEXTURE = bn_assets.load_texture("magnum_cursor.png")
local CURSOR_ANIMATION = bn_assets.fetch_animation_path("magnum_cursor.animation")
local CURSOR_SOUND = bn_assets.load_audio("magnum_cursor.ogg")

---@param user Entity
function card_init(user, props)
	local action = Action.new(user, "CHARACTER_IDLE")
	action:override_animation_frames({ { 1, 1 } })
	action:set_lockout(ActionLockout.new_sequence())

	local team = user:team()
	local direction = user:facing()
	local test_offset = 1
	if direction == Direction.Left then
		test_offset = -1
	end

	-- 敵エリアを見つけるロジック
	local function find_first_enemy_column()
		local x = user:current_tile():x()
		local found_opponent_panels = false

		-- find opponent panels ahead of us
		while not found_opponent_panels do
			x = x + test_offset

			for y = 0, Field.height() - 1 do
				local tile = Field.tile_at(x, y)

				if not tile then
					-- reached out of bounds, return nil
					return nil
				end

				if tile:team() ~= team and not tile:is_edge() then
					found_opponent_panels = true
					break
				end
			end
		end

		-- rewind to find area we've fully claimed
		while true do
			x = x - test_offset

			local has_opponent_panels = false

			for y = 0, Field.height() - 1 do
				local tile = Field.tile_at(x, y)

				if not tile then
					return nil
				end

				if tile:team() ~= team and not tile:is_edge() then
					has_opponent_panels = true
					break
				end
			end

			if not has_opponent_panels then
				break
			end
		end

		-- step forward once
		x = x + test_offset
		return x
	end

	-- カーソル表示用のスプライト配列
	local cursor_sprites = {}
	local cursor_animations = {}

	-- カーソル列を作成して表示する関数（縦3マス）
	local function create_cursors(x)
		-- 既存のカーソルを削除
		for _, sprite in ipairs(cursor_sprites) do
			sprite:delete()
		end
		cursor_sprites = {}
		cursor_animations = {}

		-- 縦3マス分のカーソルを作成
		for y = 0, Field.height() - 1 do
			local tile = Field.tile_at(x, y)

			if tile and not tile:is_edge() then
				local sprite = Spell.new(team)
				sprite:set_texture(CURSOR_TEXTURE)
				sprite:set_facing(direction)
				sprite:ignore_hole_tiles(true)
				sprite:ignore_negative_tile_effects(true)
				sprite:set_layer(-1)
				
				local anim = sprite:animation()
				anim:load(CURSOR_ANIMATION)
				anim:set_state("DEFAULT")
				anim:set_playback(Playback.Loop)
				
				Field.spawn(sprite, tile)
				
				table.insert(cursor_sprites, sprite)
				table.insert(cursor_animations, anim)
			end
		end

		-- カーソル表示音を再生
		Resources.play_audio(CURSOR_SOUND, AudioBehavior.Default)
	end

	-- 横3マスのカーソルを作成して表示する関数
	local function create_horizontal_cursors(y)
		-- 既存のカーソルを削除
		for _, sprite in ipairs(cursor_sprites) do
			sprite:delete()
		end
		cursor_sprites = {}
		cursor_animations = {}

		-- 自分のエリアの最後列を見つける
		local player_x = user:current_tile():x()
		local last_own_x = player_x
		
		-- プレイヤーの後方に向かって自分のエリアを探す
		local back_offset = -test_offset
		for i = 1, 10 do
			local check_x = player_x + (back_offset * i)
			local check_tile = Field.tile_at(check_x, 1)
			
			if not check_tile or check_tile:is_edge() then
				break
			end
			
			if check_tile:team() == team then
				last_own_x = check_x
			else
				break
			end
		end

		-- 最後列から3,4,5列目の横3マスを作成
		for offset = 3, 5 do
			local x = last_own_x + (test_offset * offset)
			local tile = Field.tile_at(x, y)

			if tile and not tile:is_edge() then
				local sprite = Spell.new(team)
				sprite:set_texture(CURSOR_TEXTURE)
				sprite:set_facing(direction)
				sprite:ignore_hole_tiles(true)
				sprite:ignore_negative_tile_effects(true)
				sprite:set_layer(-1)
				
				local anim = sprite:animation()
				anim:load(CURSOR_ANIMATION)
				anim:set_state("DEFAULT")
				anim:set_playback(Playback.Loop)
				
				Field.spawn(sprite, tile)
				
				table.insert(cursor_sprites, sprite)
				table.insert(cursor_animations, anim)
			end
		end

		-- カーソル表示音を再生
		Resources.play_audio(CURSOR_SOUND, AudioBehavior.Default)
	end

	-- カーソル移動のステップ
	local cursor_step = action:create_step()
	local frame_count = 0
	local move_count = 0
	local current_x = nil
	local start_x = nil
	local confirmed = false
	local confirmed_x = nil
	local confirmed_y = 1  -- デフォルト値を設定
	local is_horizontal_mode = false
	local horizontal_y = 1
	local is_horizontal = false

	cursor_step.on_update_func = function()
		frame_count = frame_count + 1

		-- 最初のフレームで開始位置を決定
		if frame_count == 1 then
			current_x = find_first_enemy_column()
			if not current_x then
				-- エリアが見つからない場合は終了
				cursor_step:complete_step()
				return
			end
			start_x = current_x
			create_cursors(current_x)
			move_count = 1  -- 最初の表示も1回とカウント
		end

		-- 入力チェック：使用ボタン（Useボタン）で確定
		if not confirmed and user:input_has(Input.Pressed.Use) then
			confirmed = true
			confirmed_x = current_x
			confirmed_y = horizontal_y
			is_horizontal = is_horizontal_mode
			
			-- カーソルを削除
			for _, sprite in ipairs(cursor_sprites) do
				sprite:delete()
			end
			cursor_sprites = {}
			cursor_animations = {}
			
			cursor_step:complete_step()
			return
		end

		-- 25回移動で自動確定（26回目の移動タイミングで確定）
		if not confirmed and move_count >= 25 and frame_count % 12 == 0 and frame_count > 1 then
			confirmed = true
			confirmed_x = current_x
			confirmed_y = horizontal_y
			is_horizontal = is_horizontal_mode
			
			-- カーソルを削除
			for _, sprite in ipairs(cursor_sprites) do
				sprite:delete()
			end
			cursor_sprites = {}
			cursor_animations = {}
			
			cursor_step:complete_step()
			return
		end

		-- 12フレームごとにカーソル移動
		if not confirmed and frame_count % 12 == 0 and frame_count > 1 then
			if not is_horizontal_mode then
				-- 縦列モード
				local next_x = current_x + test_offset
				local next_tile = Field.tile_at(next_x, 1)

				-- エッジタイルに到達したか確認
				if not next_tile or next_tile:is_edge() then
					-- 横3マスモードに切り替え
					is_horizontal_mode = true
					horizontal_y = 1
					create_horizontal_cursors(horizontal_y)
				else
					current_x = next_x
					create_cursors(current_x)
				end
			else
				-- 横3マスモード
				horizontal_y = horizontal_y + 1
				
				if horizontal_y > 3 then
					-- y=3まで終わったら縦列モードに戻る
					is_horizontal_mode = false
					current_x = start_x
					create_cursors(current_x)
				else
					create_horizontal_cursors(horizontal_y)
				end
			end
			
			move_count = move_count + 1
		end
	end

	-- 30フレーム待機ステップ
	local wait_step = action:create_step()
	local wait_count = 0

	wait_step.on_update_func = function()
		wait_count = wait_count + 1

		if wait_count >= 30 then
			wait_step:complete_step()
		end
	end

	-- 爆発ステップ
	local explosion_step = action:create_step()
	local explosion_count = 0
	local explosions_created = false

	explosion_step.on_update_func = function()
		-- 最初のフレームで爆発を生成
		if not explosions_created then
			explosions_created = true

			-- CHARACTER_SWING_HANDアニメーションを再生
			local user_animation = user:animation()
			if user_animation:has_state("CHARACTER_SWING_HAND") then
				user_animation:set_state("CHARACTER_SWING_HAND")
			else
				user_animation:set_state("CHARACTER_SHOOT")
			end

			-- 確定した位置に爆発と攻撃を生成
			if is_horizontal then
				-- 横3マスモード：自分のエリアの最後列から4,5,6列目
				local player_x = user:current_tile():x()
				local last_own_x = player_x
				
				-- プレイヤーの後方に向かって自分のエリアを探す
				local back_offset = -test_offset
				for i = 1, 10 do
					local check_x = player_x + (back_offset * i)
					local check_tile = Field.tile_at(check_x, 1)
					
					if not check_tile or check_tile:is_edge() then
						break
					end
					
					if check_tile:team() == team then
						last_own_x = check_x
					else
						break
					end
				end

				-- 最後列から3,4,5列目の横3マスに爆発
				for offset = 3, 5 do
					local x = last_own_x + (test_offset * offset)
					local tile = Field.tile_at(x, confirmed_y)

					if tile and not tile:is_edge() then
						-- 爆発エフェクトを生成
						local explosion = Explosion.new(team)
						Field.spawn(explosion, tile)

						-- タイル状態を変更（Bladia2の方式）
						if tile:can_set_state(TileState.Broken) then
							-- 敵がいない場合はBrokenに
							tile:set_state(TileState.Broken)
						elseif tile:can_set_state(TileState.Cracked) then
							-- 敵がいる場合はCrackedに
							tile:set_state(TileState.Cracked)
						end

						-- 攻撃用のスペルを生成
						local spell = Spell.new(team)
						spell:set_hit_props(HitProps.from_card(props, user:context(), Drag.None))
						spell:hide()
						
						Field.spawn(spell, tile)
						
						spell.on_update_func = function()
							spell:attack_tile()
							spell:delete()
						end
					end
				end
			else
				-- 縦列モード：確定した列全体
				for y = 0, Field.height() - 1 do
					local tile = Field.tile_at(confirmed_x, y)

					if tile and not tile:is_edge() then
						-- 爆発エフェクトを生成
						local explosion = Explosion.new(team)
						Field.spawn(explosion, tile)

						-- タイル状態を変更（Bladia2の方式）
						if tile:can_set_state(TileState.Broken) then
							-- 敵がいない場合はBrokenに
							tile:set_state(TileState.Broken)
						elseif tile:can_set_state(TileState.Cracked) then
							-- 敵がいる場合はCrackedに
							tile:set_state(TileState.Cracked)
						end

						-- 攻撃用のスペルを生成
						local spell = Spell.new(team)
						spell:set_hit_props(HitProps.from_card(props, user:context(), Drag.None))
						spell:hide()
						
						Field.spawn(spell, tile)
						
						spell.on_update_func = function()
							spell:attack_tile()
							spell:delete()
						end
					end
				end
			end
		end

		explosion_count = explosion_count + 1

		-- 30フレーム待機後に終了
		if explosion_count >= 30 then
			explosion_step:complete_step()
		end
	end

	action.on_action_end_func = function()
		-- 念のため残っているカーソルを削除
		for _, sprite in ipairs(cursor_sprites) do
			if not sprite:deleted() then
				sprite:delete()
			end
		end
	end

	return action
end
