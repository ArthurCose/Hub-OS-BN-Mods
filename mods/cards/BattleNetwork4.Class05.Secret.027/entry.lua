local bn_assets = require("BattleNetwork.Assets")

local bomb_texture = bn_assets.load_texture("MetlGer.png")
local bomb_anim_path = bn_assets.fetch_animation_path("MetlGer.animation")

local spawn_audio = bn_assets.load_audio("obstacle_spawn.ogg")
local guard_audio = bn_assets.load_audio("guard.ogg")
local explosion_audio = bn_assets.load_audio("explosion_defeatedboss.ogg")

-- ガードインパクト用のリソース
local guard_impact_texture = bn_assets.load_texture("shield_impact.png")
local guard_impact_anim_path = bn_assets.fetch_animation_path("shield_impact.animation")

---@param user Entity
---@param tile Tile
local function is_dest_valid(user, tile)
	return not tile:is_reserved() and
			tile:is_walkable() and
			tile:team() ~= user:team()
end

---@param user Entity
local function find_dest(user)
	local ahead = user:get_tile(user:facing(), 1)

	while ahead do
		if is_dest_valid(user, ahead) then
			return ahead
		end

		ahead = ahead:get_tile(user:facing(), 1)
	end

	-- trying every row
	local start_x, end_x, inc_x = 0, Field.width(), 1
	local end_y = Field.height() - 1

	local function flip_range()
		start_x, end_x = end_x, start_x
		inc_x = -inc_x
	end

	if user:facing() == Direction.Left then
		-- flip the range to make sure we test the frontmost tiles first
		flip_range()
	end

	for x = start_x, end_x, inc_x do
		for y = 0, end_y do
			local tile = Field.tile_at(x, y)

			-- tile must be facing away to avoid placing behind when surrounded
			if tile and is_dest_valid(user, tile) and tile:facing() == user:facing_away() then
				return tile
			end
		end
	end

	-- test in the other direction in case we're surrounded or in multi-man
	-- we flip the range to target the frontmost tile
	flip_range()

	for x = start_x, end_x, inc_x do
		for y = 0, end_y do
			local tile = Field.tile_at(x, y)

			-- ignoring tile facing direction this time
			if tile and is_dest_valid(user, tile) then
				return tile
			end
		end
	end
end

function card_init(user, props)
	local action = Action.new(user)
	local step = action:create_step()

	action:set_lockout(ActionLockout.new_sequence())

	local time = 0

	step.on_update_func = function()
		time = time + 1
	end

	action.on_execute_func = function()
		local spawn_tile = find_dest(user)

		if not spawn_tile then
			action:end_action()
			return
		end

		local bomb = Obstacle.new(Team.Other)

		bomb:set_owner(user)

		bomb:add_aux_prop(AuxProp.new():declare_immunity(~Hit.Drag))
		bomb.can_move_to_func = function(tile)
			return tile:is_walkable()
		end

		bomb:set_health(props.damage)
		bomb:set_height(80)

		local bomb_sprite = bomb:sprite()
		bomb_sprite:set_texture(bomb_texture)
		bomb_sprite:set_never_flip(true)

		-- Bladiaのように手動更新するためAnimation.new()を使用
		local bomb_animation = Animation.new()
		bomb_animation:load(bomb_anim_path)
		-- 初動のアニメーション状態（青チームは逆）
		if user:team() == Team.Blue then
			bomb_animation:set_state("DEFAULT_REVERSE")
		else
			bomb_animation:set_state("DEFAULT")
		end
		bomb_animation:set_playback(Playback.Loop)
		bomb_animation:apply(bomb_sprite)
		-- 召喚時はアニメーションを更新しない（手動更新）

		step:complete_step()
		action:set_lockout(ActionLockout.new_async(30))

		bomb:enable_hitbox(true)
		-- ガード機能の実装（Break属性とPierceGuard以外の攻撃をガード）
		local guard_defense = DefenseRule.new(DefensePriority.Body, DefenseOrder.CollisionOnly)
		guard_defense.defense_func = function(defense, attacker, defender, hit_props)
			-- Break属性またはPierceGuardを持つ攻撃かチェック
			local has_break = hit_props.element == Element.Break
			local has_pierce_guard = (hit_props.flags & Hit.PierceGuard) ~= 0

			if has_break or has_pierce_guard then
				-- Break属性またはPierceGuardの場合、即座に破壊
				-- ダメージは通す（破壊処理はon_delete_funcで実行）
				return
			end

			-- それ以外の攻撃はガード
			-- ガードインパクトエフェクトを表示
			Resources.play_audio(guard_audio)

			local guard_effect = Artifact.new()
			guard_effect:set_texture(guard_impact_texture)
			guard_effect:set_facing(bomb:facing())

			local effect_sprite = guard_effect:sprite()
			effect_sprite:set_layer(-2)
			local width = bomb_sprite:width()
			local height = bomb:height()

			effect_sprite:set_offset(
				math.random(-width * 0.25, width * 0.25),
				math.random(-height * 0.25, -height * 0.25)
			)

			local effect_anim = guard_effect:animation()
			effect_anim:load(guard_impact_anim_path)
			effect_anim:set_state("DEFAULT")
			effect_anim:on_complete(function()
				guard_effect:delete()
			end)

			Field.spawn(guard_effect, bomb:current_tile())

			-- ダメージをブロック
			defense:block_damage()
		end
		bomb:add_defense_rule(guard_defense)

		-- 30秒タイマー (60fps * 30 = 1800フレーム)
		local timer = 0
		local max_time = 1800 -- 30秒
		local blink_start_time = 1740 -- 29秒
		local blink_counter = 0
		
		-- 移動制御用の変数
		local move_counter = 30 -- 設置後すぐに動き出すように初期値を設定
		local move_delay = 60 -- 移動速度（フレーム数、大きいほど遅い）
		local is_forward = true -- true: プレイヤーの向きに進む, false: 逆方向に進む
		local user_facing = user:facing() -- プレイヤーの向き
		local user_team = user:team() -- プレイヤーのチーム
		local current_direction = user_facing -- 現在の進行方向
		local prev_tile = nil -- 前回いたタイル（クラック→穴の判定用）

		bomb.on_spawn_func = function()
			Resources.play_audio(spawn_audio)
			-- タイルにハイライト表示
			local current_tile = bomb:current_tile()
			if current_tile then
				current_tile:set_highlight(Highlight.Solid)
			end
		end

		bomb.on_update_func = function()
			if TurnGauge.frozen() == true then return end

			-- タイムフリーズが明けたらアニメーションを更新
			bomb_animation:update()
			bomb_animation:apply(bomb_sprite)

			-- タイルのハイライトを維持
			local current_tile = bomb:current_tile()
			if current_tile then
				current_tile:set_highlight(Highlight.Solid)
				
				-- 現在のタイルでキャラクターとの衝突判定
				local characters = current_tile:find_characters(function(character)
					return character:id() ~= bomb:id() and character:hittable()
				end)
				
				if #characters > 0 then
					-- プレイヤーやキャラクターと衝突：ダメージを与えて破壊
					for _, character in ipairs(characters) do
						local hit_props = HitProps.from_card(props, bomb:context())
						character:hit(hit_props)
					end
					bomb:delete()
					return
				end
			end

			timer = timer + 1
			
			-- 移動処理
			move_counter = move_counter + 1
			if move_counter >= move_delay then
				move_counter = 0
				
				-- 前回いたタイルがクラックなら穴にする
				if prev_tile and prev_tile:state() == TileState.Cracked then
					if prev_tile:can_set_state(TileState.Broken) then
						prev_tile:set_state(TileState.Broken)
					end
				end
				
				-- 次のタイルを取得
				local next_tile = current_tile:get_tile(current_direction, 1)
				
				-- 移動可能かチェック
				local can_move = false
				local should_reverse = false
				
				if next_tile then
					-- エッジタイルかチェック
					if next_tile:is_edge() then
						should_reverse = true
					-- 穴タイルかチェック
					elseif not next_tile:is_walkable() then
						should_reverse = true
					-- 逆方向の時：自分のエリアに入る前に反転（置物チェックより優先）
					elseif not is_forward and next_tile:team() == user_team then
						should_reverse = true
					-- 置物がいるかチェック（移動前は置物のみチェック）
					elseif next_tile:is_reserved() then
						local obstacles = next_tile:find_obstacles(function(obstacle)
							return obstacle:id() ~= bomb:id()
						end)
						if #obstacles > 0 then
							should_reverse = true
						else
							can_move = true
						end
					else
						can_move = true
					end
				else
					should_reverse = true
				end
				
				-- 方向転換
				if should_reverse then
					is_forward = not is_forward
					local new_state
					if is_forward then
						-- 前方向に戻る
						current_direction = user_facing
						if user_team == Team.Blue then
							new_state = "DEFAULT_REVERSE"
						else
							new_state = "DEFAULT"
						end
					else
						-- 逆方向に進む
						current_direction = Direction.reverse(user_facing)
						if user_team == Team.Blue then
							new_state = "DEFAULT"
						else
							new_state = "DEFAULT_REVERSE"
						end
					end
					
					-- 現在の状態と異なる場合のみ変更
					if bomb_animation:state() ~= new_state then
						bomb_animation:set_state(new_state)
						bomb_animation:set_playback(Playback.Loop)
						bomb_animation:apply(bomb_sprite)
					end
					
					-- 方向転換後、即座に移動開始
					local reverse_tile = current_tile:get_tile(current_direction, 1)
					if reverse_tile and reverse_tile:is_walkable() and not reverse_tile:is_edge() then
						prev_tile = current_tile
						bomb:slide(reverse_tile, move_delay - 2)
					end
				-- 移動実行
				elseif can_move and next_tile then
					prev_tile = current_tile
					bomb:slide(next_tile, move_delay - 2)
				end
			end

			-- 29秒以降は2フレームごとに点滅
			if timer >= blink_start_time then
				blink_counter = blink_counter + 1
				if blink_counter >= 2 then
					blink_counter = 0
					if bomb_sprite:visible() then
						bomb_sprite:hide()
					else
						bomb_sprite:reveal()
					end
				end
			end

			-- 30秒になったら消える
			if timer >= max_time then
				bomb:erase()
			end
		end

		bomb.on_delete_func = function()
			-- ハイライトを解除
			local current_tile = bomb:current_tile()
			if current_tile then
				current_tile:set_highlight(Highlight.None)
			end
			
			-- Bladiaのように爆発エフェクトを表示
			Resources.play_audio(explosion_audio, AudioBehavior.NoOverlap)
			local explosion = Explosion.new()
			local offset = bomb:movement_offset()
			explosion:set_offset(offset.x, offset.y)
			Field.spawn(explosion, current_tile)
			bomb:erase()
		end
		Field.spawn(bomb, spawn_tile)
	end

	return action
end
