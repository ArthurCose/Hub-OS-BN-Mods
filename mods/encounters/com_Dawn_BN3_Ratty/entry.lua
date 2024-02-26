local character_id = "BattleNetwork3.Ratty.Enemy"

-- function package_requires_scripts()
--     Engine.define_character(character_id, "virus")
-- end

function encounter_init(mob)
    -- local texPath = "background.png"
    -- local animPath = "background.animation"
    -- mob:set_background(texPath, animPath, 1.0, 0.0)
    mob:set_music("music.mid", 0, 0)

    mob:create_spawner(character_id, Rank.V1)
        :spawn_at(4, 1)
    mob:create_spawner(character_id, Rank.V2)
        :spawn_at(5, 2)
    mob:create_spawner(character_id, Rank.V3)
        :spawn_at(4, 3)
end