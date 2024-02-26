local package_id = "EXE5.Bladia"
local character_id = "EXE5.Bladia.Enemy"





function encounter_init(mob, data)
    --Make it a liberation fight.
    mob:enable_freedom_mission(3, false)
    --You may change this 1 to any number up to 6, and fight a higher rank Bladia.
    local rank = "1"
    --Liberation missions sometimes call up a higher rank from server side.
    if data and data.rank then rank = data.rank end
    --In case the server has converted it to an integer, we use tostring()
    mob:create_spawner(character_id..tostring(rank), Rank.V1):spawn_at(5, 2):mutate(function(character)
        if data and data.health then
            print("mutating")
            character:set_health(data.health)
        end
    end)
end
