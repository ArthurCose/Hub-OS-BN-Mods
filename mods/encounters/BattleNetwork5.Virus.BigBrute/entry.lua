function encounter_init(mob)
    --can setup backgrounds, music, and field here
    local test_spawner = mob:create_spawner("BattleNetwork5.Character.BigBrute", Rank.V1)
    test_spawner:spawn_at(5, 2)
    --test_spawner:spawn_at(6, 2)
    --test_spawner:spawn_at(4, 2)
end
