local bn_assets = require("BattleNetwork.Assets")

local lance_audio = bn_assets.load_audio("sword.ogg")

local sidbmbo_texture = bn_assets.load_texture("sidbmbo.png")
local sidbmbo_anim_path = bn_assets.fetch_animation_path("sidbmbo.animation")

local function spawn_animation_effect(tile, user)
	local spell = Spell.new(user:team())
	spell:sprite():set_texture(sidbmbo_texture)
	spell:sprite():set_layer(-1)
	spell:set_offset(0, -5)  -- 5px上に表示
	
	local anim = spell:animation()
	anim:load(sidbmbo_anim_path)
	anim:set_state("DEFAULT")
	anim:on_complete(function()
		spell:erase()
	end)
	
	Field.spawn(spell, tile)
end

function card_init(actor, props)
	local action = Action.new(actor, "CHARACTER_IDLE")

	action:set_lockout(ActionLockout.new_async(40))

	action.on_execute_func = function(self, user)
		-- 自分の3マス前の位置を計算
		local user_tile = user:current_tile()
		local target_tile = user_tile:get_tile(user:facing(), 3)
		
		if not target_tile or target_tile:is_edge() then
			return
		end
		
		-- y=1の位置にアニメーションを表示（エッジタイルを除く最初の行）
		local anim_tile = Field.tile_at(target_tile:x(), 1)
		if anim_tile and not anim_tile:is_edge() then
			spawn_animation_effect(anim_tile, user)
		end
		
		-- 攻撃判定管理用の変数
		local frame_counter = 0
		local spells = {}
		local hit_occurred = false
		local x = target_tile:x()
		
		-- ActionStepを使用して毎フレーム処理
		local step = self:create_step()
		step.on_update_func = function(step_self)
			frame_counter = frame_counter + 1
			
			-- 20フレーム目にすべての攻撃判定を消す
			if frame_counter == 20 then
				for _, spell in ipairs(spells) do
					if not spell:deleted() then
						spell:erase()
					end
				end
				step_self:complete_step()
				return
			end
			
			-- ヒットが発生していたら新しい攻撃判定を追加しない
			if hit_occurred then
				return
			end
			
			local y_pos = nil
			
			-- 7フレーム目：y=1の攻撃判定
			if frame_counter == 7 then
				y_pos = 1
			-- 9フレーム目：y=2の攻撃判定
			elseif frame_counter == 9 then
				y_pos = 2
			-- 11フレーム目：y=3の攻撃判定
			elseif frame_counter == 11 then
				y_pos = 3
			end
			
			if y_pos then
				local tile = Field.tile_at(x, y_pos)
				
				if tile and not tile:is_edge() then
					local spell = Spell.new(user:team())
					spell:set_facing(user:facing_away())
					spell:set_hit_props(
						HitProps.from_card(
							props,
							user:context(),
							Drag.new(Direction.Down, 2)
						)
					)
					
					-- スプライトを非表示にする
					spell:sprite():hide()
					
					-- 攻撃がヒットしたらフラグを立てる
					spell.on_attack_func = function(self, entity)
						hit_occurred = true
						-- すべての攻撃判定を消す
						for _, s in ipairs(spells) do
							if not s:deleted() then
								s:erase()
							end
						end
					end
					
					spell.on_update_func = function(self)
						self:attack_tile()
					end
					
					Field.spawn(spell, tile)
					table.insert(spells, spell)
				end
			end
		end

		Resources.play_audio(lance_audio)
	end
	return action
end
