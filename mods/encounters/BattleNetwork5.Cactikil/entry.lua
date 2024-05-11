local cactikil_id = "BattleNetwork5.Cactikil.Enemy"
local cactroll_id = "BattleNetwork5.Cactroll.Enemy"
local cacter_id = "BattleNetwork5.Cacter.Enemy"


function encounter_init(mob)
    mob
        :create_spawner(cactikil_id, Rank.V1)
        :spawn_at(5, 2)
    mob
        :create_spawner(cactikil_id, Rank.EX)
        :spawn_at(6, 2)

    mob
        :create_spawner(cactroll_id, Rank.V1)
        :spawn_at(5, 1)
    mob
        :create_spawner(cactroll_id, Rank.EX)
        :spawn_at(6, 1)

    mob
        :create_spawner(cacter_id, Rank.V1)
        :spawn_at(5, 3)
    mob
        :create_spawner(cacter_id, Rank.EX)
        :spawn_at(6, 3)

    mob:field():tile_at(3, 2):set_state(TileState.Broken)
end
