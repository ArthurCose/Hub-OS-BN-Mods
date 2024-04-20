local character_id = "BattleNetwork3.enemy."

function encounter_init(mob)
    local spawner = mob:create_spawner(character_id .. "KillerEye", Rank.V1)
    spawner:spawn_at(4, 1)
    spawner = mob:create_spawner(character_id .. "DemonEye", Rank.V1)
    spawner:spawn_at(4, 3)
    spawner = mob:create_spawner(character_id .. "JokerEye", Rank.V1)
    spawner:spawn_at(6, 1)

    local spawner = mob:create_spawner(character_id .. "KillerEye", Rank.SP)
    spawner:spawn_at(6, 3)
    -- spawner = mob:create_spawner(character_id .. "KillerEye",Rank.Rare1)
    -- spawner:spawn_at(5, 3)
    -- spawner = mob:create_spawner(character_id .. "KillerEye",Rank.Rare2)
    -- spawner:spawn_at(5, 2)
end
