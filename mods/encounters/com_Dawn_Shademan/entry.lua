local shademan_id = "Dawn.Enemy.Shademan"
local shademan_alpha_id = "Dawn.Enemy.ShademanAlpha"
local shademan_beta_id = "Dawn.Enemy.ShademanBeta"

function encounter_init(mob)
    local texPath = "BG.png"
    local animPath = "BG.animation"
    mob:set_background(texPath, animPath, 0.5, -0.3)
    mob:set_music("song.mid", 0, 0)
    mob:create_spawner(shademan_id, Rank.V1):spawn_at(5, 2)
    -- mob:create_spawner(shademan_alpha_id, Rank.EX):spawn_at(6, 1)
    -- mob:create_spawner(shademan_beta_id, Rank.SP):spawn_at(6, 3)
end
