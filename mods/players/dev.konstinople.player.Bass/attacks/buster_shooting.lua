--- Inspired by the exe 4.5 pvp patch by GreigaMaster https://www.therockmanexezone.com/pages/exe45-pvp-patch/preview1.html
--- Specific changes in this mod from base 4.5:
---  - Targeted tiles are highlighted before spawning an attack
---  - The same tile will not be targeted twice in a row
---  - The tile with the opponent will be targeted when possible
---  - An 8 frame animation plays before attacking (counterable during this time)
---  - Only tiles in front of bass will be targeted

---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local SHOT_TEXTURE = bn_assets.load_texture("gunner_shot_burst.png")
local SHOT_ANIMATION = bn_assets.fetch_animation_path("gunner_shot_burst.animation")
local SHOT_SFX = bn_assets.load_audio("gunner_shot.ogg")
local IMPACT_SFX = bn_assets.load_audio("hit_impact.ogg")

local HIT_TEXTURE = bn_assets.load_texture("bn6_hit_effects.png")
local HIT_ANIM_PATH = bn_assets.fetch_animation_path("bn6_hit_effects.animation")

local MAX_SHOTS = 8

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

---@param user Entity
local function find_target_position(user)
    local team = user:team()
    local direction = user:facing()
    local current_tile = user:current_tile()
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

    local enemies = Field.find_nearest_characters(user, function(character)
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
            x = Field.width() - 2
        else
            x = 2
        end

        y = current_tile:y()
    end

    return x, y
end

---@param user Entity
return function(user)
    local hit_props = HitProps.new(
        user:attack_level() * 3,
        Hit.Impact | Hit.PierceGround,
        Element.None,
        user:context()
    )

    local action = Action.new(user, "CHARACTER_BUSTER_SHOOTING_START")
    action:set_lockout(ActionLockout.new_sequence())

    local animation = user:animation()

    ---@type Tile[]
    local target_tiles = {}

    local function set_target_tiles(x, y)
        local tile_pool = {}

        local x_start = x - 1
        local x_end = x + 1

        local user_x = user:current_tile():x()

        if user:facing() == Direction.Right then
            x_start = math.max(user_x + 1, x_start)
        else
            x_end = math.min(user_x - 1, x_start)
        end

        for i = x_start, x_end do
            for j = y - 1, y + 1 do
                if x == i and y == j then
                    goto continue
                end

                local tile = Field.tile_at(i, j)

                if tile and not tile:is_edge() then
                    tile_pool[#tile_pool + 1] = tile
                end

                ::continue::
            end
        end

        local prev_a = target_tiles[1]
        local prev_b = target_tiles[2]
        target_tiles[1] = nil
        target_tiles[2] = nil

        local next_tile = Field.tile_at(x, y)

        while #target_tiles < 2 do
            if next_tile ~= prev_a and next_tile ~= prev_b then
                target_tiles[#target_tiles + 1] = next_tile
            end

            if #tile_pool == 0 then
                break
            end

            next_tile = table.remove(tile_pool, math.random(#tile_pool))
        end
    end

    local start_step = action:create_step()

    action.on_execute_func = function()
        animation:set_playback(Playback.Loop)
        user:set_counterable(true)

        local i = 0
        animation:on_complete(function()
            i = i + 1

            if i == 2 then
                start_step:complete_step()
                user:set_counterable(false)
                animation:set_state("CHARACTER_BUSTER_SHOOTING_LOOP")
                animation:set_playback(Playback.Loop)
            else
                local x, y = find_target_position(user)
                set_target_tiles(x, y)
            end
        end)
    end

    -- highlight tiles every frame, regardless of step
    action.on_update_func = function()
        for _, tile in ipairs(target_tiles) do
            tile:set_highlight(Highlight.Solid)
        end
    end

    action.on_action_end_func = function()
        user:set_counterable(false)
    end

    local attack_step = action:create_step()

    local time = 0
    local shots = 0

    attack_step.on_update_func = function()
        local time_remainder = time % 9

        time = time + 1

        if time_remainder ~= 0 then
            if time_remainder == 3 then
                -- hit the target tiles
                for _, tile in ipairs(target_tiles) do
                    Field.spawn(create_gunner_shot(user, hit_props), tile)
                end

                -- update target tiles
                if shots < MAX_SHOTS - 1 then
                    local x, y = find_target_position(user)
                    set_target_tiles(x, y)
                else
                    target_tiles[1] = nil
                end
            end

            return
        end

        shots = shots + 1

        if shots == MAX_SHOTS then
            attack_step.on_update_func = nil
            animation:set_state("CHARACTER_BUSTER_SHOOTING_END")
            animation:on_complete(function()
                attack_step:complete_step()
            end)
            return
        end

        -- spawn artifact
        local artifact = Artifact.new()
        local height = user:height()
        local offset_y = math.random(math.floor(-height * 0.8), math.floor(-height * 0.4))

        if user:facing() == Direction.Right then
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

        Field.spawn(artifact, user:current_tile())

        -- play sfx
        Resources.play_audio(SHOT_SFX)
    end


    return action
end
