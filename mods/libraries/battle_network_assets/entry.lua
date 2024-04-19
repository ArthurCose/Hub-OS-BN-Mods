---@class BattleNetworkAssetsLib
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

-- Poof support
Lib.ParticlePoof = {}
function Lib.ParticlePoof.new()
    local TEXTURE = Lib.load_texture("poof.png")
    local fx = Artifact.new()
    fx:set_texture(TEXTURE)

    local fx_animation = fx:animation()
    fx_animation:load(Lib.fetch_animation_path("poof.animation"))
    fx_animation:set_state("DEFAULT")
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

    local field = user:field()
    local step = action:create_step()
    local start_poof

    if not target_tile_callback then
        -- default implementation
        target_tile_callback = function()
            local current_tile = user:current_tile()
            local valid_tiles = field:find_tiles(function(tile)
                return user:can_move_to(tile) and tile ~= current_tile
            end)

            if #valid_tiles == 0 then
                return nil
            end

            return valid_tiles[math.random(#valid_tiles)]
        end
    end

    action.on_execute_func = function()
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
        field:spawn(start_poof, start_tile)
        field:spawn(end_poof, start_tile)

        local start_poof_anim = start_poof:animation()
        start_poof_anim:on_frame(2, function()
            step:complete_step()
            end_poof_anim:resume()
            end_poof_sprite:set_visible(true)

            local tile = target_tile_callback()

            if tile and user:can_move_to(tile) then
                local old_tile = user:current_tile()
                tile:add_entity(user)
                tile:reserve_for(user)
                old_tile:remove_reservation_for(user)
            end

            user:current_tile():add_entity(end_poof)
        end)
    end

    return action
end

return Lib
