---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")

local SHOT_TEXTURE = bn_assets.load_texture("gunner_shot_burst.png")
local SHOT_ANIMATION = bn_assets.fetch_animation_path("gunner_shot_burst.animation")
local SHOT_SFX = bn_assets.load_audio("gunner_shot.ogg")
local IMPACT_SFX = bn_assets.load_audio("hit_impact.ogg")

local HIT_TEXTURE = bn_assets.load_texture("bn6_hit_effects.png")
local HIT_ANIM_PATH = bn_assets.fetch_animation_path("bn6_hit_effects.animation")

---@param user Entity
local function create_gunner_shot(user, hit_props)
    local spell = Spell.new(user:team())
    spell:set_texture(SHOT_TEXTURE)
    spell:set_facing(user:facing())
    spell:set_hit_props(hit_props)
    spell:sprite():set_layer(-3)

    local animation = spell:animation()
    animation:load(SHOT_ANIMATION)
    animation:set_state("DEFAULT")

    animation:on_complete(function()
        spell:delete()
    end)

    spell.on_collision_func = function()
        Resources.play_audio(IMPACT_SFX)
    end

    spell.on_spawn_func = function()
        spell:attack_tile()
    end

    return spell
end

---@param player Entity
function player_init(player)
    player:set_height(62)
    player:load_animation("battle.animation")
    player:set_texture(Resources.load_texture("battle.png"))
    player:set_fully_charged_color(Color.new(120, 63, 152))
    player:set_charge_position(10, -35)

    -- create cape
    local cape_sync_node = player:create_sync_node()
    cape_sync_node:animation():load("cape.animation")
    local cape_sprite = cape_sync_node:sprite()
    cape_sprite:set_texture(Resources.load_texture("cape.png"))
    cape_sprite:use_root_shader(true)

    -- emotions
    local synchro = EmotionsLib.new_synchro()
    synchro:set_ring_offset(3, -35)
    synchro:implement(player)

    player.on_counter_func = function()
        player:set_emotion("SYNCHRO")
    end

    -- attacks
    player.normal_attack_func = function()
        return Buster.new(player, false, player:attack_level())
    end

    local animation = player:animation()

    player.charged_attack_func = function()
        local hit_props = HitProps.new(
            math.min(player:attack_level(), 3) * 3,
            Hit.Impact | Hit.PierceGround,
            Element.None,
            player:context()
        )

        local action = Action.new(player, "CHARACTER_BUSTER_SHOOTING_LOOP")
        action:set_lockout(ActionLockout.new_sequence())

        local time = 0
        local shots = 0
        local field = player:field()
        local target_tiles = {}

        local step = action:create_step()
        step.on_update_func = function()
            local time_remainder = time % 9

            if time_remainder == 3 then
                -- hit 2 random tiles
                for _ = 1, 2 do
                    ---@type Tile
                    local tile = target_tiles[math.random(#target_tiles)]
                    field:spawn(create_gunner_shot(player, hit_props), tile)
                end
            end

            time = time + 1

            if time_remainder ~= 0 then
                return
            end

            shots = shots + 1

            if shots == 8 then
                step.on_update_func = nil
                animation:set_state("CHARACTER_BUSTER_SHOOTING_END")
                animation:on_complete(function()
                    step:complete_step()
                end)
                return
            end

            -- find enemies
            local team = player:team()
            local direction = player:facing()
            local current_tile = player:current_tile()
            local x = current_tile:x()

            local position_comparison_func

            if direction == Direction.Right then
                position_comparison_func = function(other_x)
                    return other_x > x
                end
            else
                position_comparison_func = function(other_x)
                    return other_x < x
                end
            end

            local enemies = field:find_nearest_characters(player, function(character)
                return
                    character:team() ~= team and
                    not character:deleted() and
                    position_comparison_func(character:current_tile():x())
            end)

            -- set target position based on the nearest enemy
            local y

            if enemies[1] then
                local enemy_tile = enemies[1]:current_tile()
                x = enemy_tile:x()
                y = enemy_tile:y()
            else
                if direction == Direction.Right then
                    x = field:width() - 2
                else
                    x = 2
                end

                y = current_tile:y()
            end

            -- get a list of hittable tiles near the target position
            local center_tile = field:tile_at(x, y)
            target_tiles = { center_tile, center_tile, center_tile }

            for i = x - 1, x + 1 do
                for j = y - 1, y + 1 do
                    local tile = field:tile_at(i, j)

                    if tile and tile:is_walkable() then
                        target_tiles[#target_tiles + 1] = tile
                    end
                end
            end

            -- spawn artifact
            local artifact = Artifact.new()
            local height = player:height()
            local offset_y = math.random(math.floor(-height * 0.8), math.floor(-height * 0.4))

            if direction == Direction.Right then
                artifact:set_offset(math.random(0, Tile:width()), offset_y)
            else
                artifact:set_offset(math.random(-Tile:width(), 0), offset_y)
            end

            local artifact_sprite = artifact:sprite()
            artifact_sprite:set_texture(HIT_TEXTURE)
            artifact_sprite:set_layer(-3)

            local artifact_anim = artifact:animation()
            artifact_anim:load(HIT_ANIM_PATH)
            artifact_anim:set_state("SPARK_1")
            artifact_anim:on_complete(function()
                artifact:erase()
            end)

            field:spawn(artifact, current_tile)

            -- play sfx
            Resources.play_audio(SHOT_SFX)
        end

        action.on_execute_func = function()
            animation:set_playback(Playback.Loop)
        end

        return action
    end
end
