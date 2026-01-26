---@class BattleNetwork.Assets
local Lib = {}

local images_animations_folder = _folder_path .. "Animations & Images/"
local sounds_folder = _folder_path .. "Sounds/"

function Lib.fetch_animation_path(name)
    -- This is because we'll add the extension ourselves.
    return images_animations_folder .. name
end

function Lib.load_texture(name)
    return Resources.load_texture(images_animations_folder .. name)
end

function Lib.load_audio(name)
    return Resources.load_audio(sounds_folder .. name)
end

-- Recovery Effect support
Lib.Recovery = {}
function Lib.Recovery.new(user, heal_amount)
    local RECOVER_TEXTURE = Lib.load_texture("recover.png")
    local RECOVER_ANIMATION = Lib.fetch_animation_path("recover.animation")
    local RECOVER_AUDIO = Lib.load_audio("recover.ogg")

    local artifact = Artifact.new()
    artifact:set_texture(RECOVER_TEXTURE)
    artifact:set_facing(user:facing())
    artifact:sprite():set_layer(-1)

    local anim = artifact:animation()
    anim:load(RECOVER_ANIMATION)
    anim:set_state("DEFAULT")
    anim:on_complete(function()
        artifact:erase()
    end)

    artifact.on_spawn_func = function()
        if type(heal_amount) == "number" then
            user:set_health(math.min(user:max_health(), user:health() + heal_amount))
        end

        Resources.play_audio(RECOVER_AUDIO)
    end

    return artifact
end

-- Poof support
Lib.ParticlePoof = {}

---@param state? "BIG" | "SMALL" default is BIG
function Lib.ParticlePoof.new(state)
    local TEXTURE = Lib.load_texture("poof.png")
    local fx = Artifact.new()
    fx:set_texture(TEXTURE)

    local fx_animation = fx:animation()
    fx_animation:load(Lib.fetch_animation_path("poof.animation"))
    fx_animation:set_state(state or "BIG")
    fx_animation:on_complete(function()
        fx:erase()
    end)

    return fx
end

Lib.MobMove = {}

---@param state string
function Lib.MobMove.new(state)
    local fx = Artifact.new()
    local anim = fx:animation()

    fx:set_texture(Lib.load_texture("mob_move.png"))
    fx:sprite():set_layer(-5)

    anim:load(Lib.fetch_animation_path("mob_move.animation"))
    anim:set_state(state)
    anim:on_complete(function()
        fx:erase()
    end)

    return fx
end

Lib.MobMoveAction = {}

---@param user Entity
---@param size_prefix "BIG" | "MEDIUM" | "SMALL"
---@param target_tile_callback? fun(): Tile?
function Lib.MobMoveAction.new(user, size_prefix, target_tile_callback)
    local action = Action.new(user)
    action:set_lockout(ActionLockout.new_sequence())

    local step = action:create_step()
    local start_poof

    if not target_tile_callback then
        -- default implementation
        target_tile_callback = function()
            local current_tile = user:current_tile()
            local valid_tiles = Field.find_tiles(function(tile)
                return user:can_move_to(tile) and tile ~= current_tile
            end)

            if #valid_tiles == 0 then
                return nil
            end

            return valid_tiles[math.random(#valid_tiles)]
        end
    end

    local cancelled = false

    action.on_action_end_func = function()
        cancelled = true
    end

    action.on_execute_func = function()
        if Living.from(user) and user:is_immobile() then
            step:complete_step()
            return
        end

        start_poof = Lib.MobMove.new(size_prefix .. "_START")

        -- setup final poof early to keep animations in sync
        local end_poof = Lib.MobMove.new(size_prefix .. "_END")
        local end_poof_sprite = end_poof:sprite()
        local end_poof_anim = end_poof:animation()

        end_poof.on_spawn_func = function()
            end_poof_anim:pause()
        end

        end_poof_sprite:set_visible(false)

        local y = -user:height() / 2
        start_poof:set_offset(0, y)
        end_poof:set_offset(0, y)

        local start_tile = user:current_tile()
        Field.spawn(start_poof, start_tile)
        Field.spawn(end_poof, start_tile)

        local start_poof_anim = start_poof:animation()
        start_poof_anim:on_frame(2, function()
            if cancelled then
                end_poof:erase()
                return
            end

            step:complete_step()
            end_poof_anim:resume()
            end_poof_sprite:set_visible(true)

            local tile = target_tile_callback()

            if tile and tile ~= start_tile and user:can_move_to(tile) and (not Living.from(user) or not user:is_immobile()) then
                tile:add_entity(user)
                user:set_facing(tile:facing())
            end

            user:current_tile():add_entity(end_poof)
        end)
    end

    return action
end

Lib.HitParticle = {}

---@param state_name string
---@param offset_x? number
---@param offset_y? number
function Lib.HitParticle.new(state_name, offset_x, offset_y)
    local artifact = Artifact.new()
    artifact:set_texture(Lib.load_texture("bn6_hit_effects.png"))
    artifact:load_animation(Lib.fetch_animation_path("bn6_hit_effects.animation"))
    local animation = artifact:animation()
    animation:set_state(state_name)
    animation:on_complete(function()
        artifact:delete()
    end)

    artifact:set_offset(offset_x or 0, offset_y or 0)

    return artifact
end

return Lib
