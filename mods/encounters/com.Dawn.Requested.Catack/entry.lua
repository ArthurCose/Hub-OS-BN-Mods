function encounter_init(mob)
    mob
        :create_spawner("BattleNetwork.Enemy.Catack", Rank.V1)
        :spawn_at(4, 2)
    mob
        :create_spawner("BattleNetwork.Enemy.Catack", Rank.V2)
        :spawn_at(4, 1)
    mob
        :create_spawner("BattleNetwork.Enemy.Catack", Rank.V3)
        :spawn_at(4, 3)
    mob
        :create_spawner("BattleNetwork.Enemy.Catack", Rank.SP)
        :spawn_at(6, 2)
end
