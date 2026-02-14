---@param augment Augment
function augment_init(augment)
  local owner = augment:owner()

  augment.movement_func = function(self, direction)
    -- レベルに応じて確率を変更
    -- Level 1: 1/8, Level 2+: 4/8
    local threshold
    if augment:level() == 1 then
      threshold = 1  -- 1/8の確率
    else
      threshold = 4  -- 4/8の確率 (Level 2+)
    end
    
    local random_chance = math.random(1, 8)
    
    if random_chance <= threshold then
      -- ランダムなタイルに移動
      local player_team = owner:team()
      local current_tile = owner:current_tile()
      local valid_tiles = {}
      
      -- 自分のチームの移動可能なタイルを探す
      local all_tiles = Field.find_tiles(function(tile)
        return tile:team() == player_team and owner:can_move_to(tile)
      end)
      
      for _, tile in ipairs(all_tiles) do
        table.insert(valid_tiles, tile)
      end
      
      -- ランダムなタイルに移動
      if #valid_tiles > 0 then
        local random_tile = valid_tiles[math.random(1, #valid_tiles)]
        owner:queue_default_player_movement(random_tile)
      end
    else
      -- 通常の1マス移動
      local vector = Direction.vector(direction)
      local start_tile = owner:current_tile()
      local dest_tile = Field.tile_at(start_tile:x() + vector.x, start_tile:y() + vector.y)
      
      if dest_tile and owner:can_move_to(dest_tile) then
        owner:queue_default_player_movement(dest_tile)
      end
    end
  end

  owner:boost_augment("BattleNetwork.Bugs.EmotionFlicker", 1)

  augment.on_delete_func = function()
    owner:boost_augment("BattleNetwork.Bugs.EmotionFlicker", -1)
  end
end
