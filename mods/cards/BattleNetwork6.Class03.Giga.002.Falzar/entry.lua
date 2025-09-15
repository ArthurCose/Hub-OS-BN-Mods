---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local EXPLOSION_SFX = bn_assets.load_audio("explosion_defeatedmob.ogg")

local FIST_TEXTURE = bn_assets.load_texture("duo_fist.png")
local FIST_ANIM_PATH = bn_assets.fetch_animation_path("duo_fist.animation")

local RING_EXPLOSION_TEXTURE = bn_assets.load_texture("ring_explosion.png")
local RING_EXPLOSION_ANIM_PATH = bn_assets.fetch_animation_path("ring_explosion.animation")

local function spawn_explosion(tile)
    local artifact = Artifact.new()
    artifact:set_texture(RING_EXPLOSION_TEXTURE)
    artifact:set_layer(-1)

    local animation = artifact:animation()
    animation:load(RING_EXPLOSION_ANIM_PATH)
    animation:set_state("DEFAULT")
    animation:on_complete(function()
        artifact:delete()
    end)

    Resources.play_audio(EXPLOSION_SFX)

    Field.spawn(artifact, tile)
end

local function create_fist(user, hit_props)
    local spell = Spell.new(user:team())
    spell:set_facing(user:facing())
    spell:set_hit_props(hit_props)
    spell:set_texture(FIST_TEXTURE)
    spell:set_layer(-2)

    local animation = spell:animation()
    animation:load(FIST_ANIM_PATH)
    animation:set_state("DEFAULT")

    local time = 8

    local rise_update_func = function()
        time = time + 1

        local x_offset = time * -16

        if spell:facing() == Direction.Left then
            x_offset = -x_offset
        end

        spell:set_offset(x_offset, time * -16)

        if time >= 6 then
            spell:delete()
        end
    end

    local wait_update_func = function()
        time = time + 1

        if time >= 2 then
            time = 0
            spell.on_update_func = rise_update_func
        end
    end

    local fall_update_func = function()
        time = time - 1

        local x_offset = time * -16

        if spell:facing() == Direction.Left then
            x_offset = -x_offset
        end

        spell:set_offset(x_offset, time * -16)

        if time > 0 then
            return
        end

        spawn_explosion(spell:current_tile())
        spell:attack_tile()
        Field.shake(3, 30)

        spell.on_update_func = wait_update_func

        local current_tile = spell:current_tile()

        if current_tile:state() == TileState.Cracked then
            current_tile:set_state(TileState.Broken)
        else
            current_tile:set_state(TileState.Cracked)
        end
    end

    spell.on_update_func = fall_update_func

    return spell
end

local function find_target_tile(team, last_tile)
    local targetted = {}
    local tiles = {}

    Field.find_characters(function(c)
        if not c:hittable() or c:team() == team then
            return false
        end

        local center_tile = c:current_tile()
        local center_x = center_tile:x()
        local center_y = center_tile:y()

        for x = center_x - 1, center_x + 1 do
            for y = center_y - 1, center_y + 1 do
                local tile = Field.tile_at(x, y)

                if tile and tile:team() ~= team and not tile:is_edge() and not targetted[tile] and last_tile ~= tile then
                    tiles[#tiles + 1] = tile
                    targetted[tile] = tile
                end
            end
        end

        return false
    end)

    if #tiles == 0 then
        return nil
    end

    return tiles[math.random(#tiles)]
end

---@param tile Tile
local function tile_contains_hittable_enemy(tile, team)
    local result = false

    tile:find_characters(function(c)
        if c:hittable() and c:team() ~= team then
            result = true
        end
        return false
    end)

    return result
end

---@param user Entity
function card_init(user, props)
    local action = Action.new(user)
    action:set_lockout(ActionLockout.new_sequence())

    action:create_step()

    action.on_execute_func = function()
        local team = user:team()
        local hit_props = HitProps.from_card(props, user:context())

        local time = 0
        local fists = 0
        local last_tile = nil
        local hit_opponent = false

        action.on_update_func = function()
            local prev_time = time

            time = time + 1

            if prev_time % 8 ~= 0 then
                return
            end

            if fists >= 16 then
                action:end_action()
                return
            end

            fists = fists + 1

            local tile

            if fists < 16 or hit_opponent then
                tile = find_target_tile(team, last_tile)

                if tile and not hit_opponent then
                    hit_opponent = tile_contains_hittable_enemy(tile, team)
                end
            else
                -- target a random opponent if we haven't hit anyone
                local characters = Field.find_characters(function(c)
                    return c:hittable() and c:team() ~= team and c:current_tile():team() ~= team
                end)

                if #characters > 0 then
                    characters[math.random(#characters)]:current_tile()
                end
            end

            if not tile then
                -- hit a random opponent tile
                local tiles = Field.find_tiles(function(tile)
                    return tile:team() ~= team and not tile:is_edge()
                end)

                if #tiles == 0 then
                    return
                end

                tile = tiles[math.random(#tiles)]
            end

            last_tile = tile

            local fist = create_fist(user, hit_props)
            Field.spawn(fist, tile)
        end
    end

    return action
end
