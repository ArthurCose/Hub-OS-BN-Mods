---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local BUSTER_TEXTURE = bn_assets.load_texture("magcoil_buster.png")
local BUSTER_ANIMATION_PATH = bn_assets.fetch_animation_path("magcoil_buster.animation")
local COIL_TEXTURE = bn_assets.load_texture("magcoil.png")
local COIL_ANIMATION_PATH = bn_assets.fetch_animation_path("magcoil.animation")
local SFX = bn_assets.load_audio("elecpulse.ogg")

---@param tile Tile
---@param direction Direction
local function pull_to_tile(tile, direction)
    local from_tile = tile:get_tile(direction, 1)

    if not from_tile then
        return
    end

    local pull_direction = Direction.reverse(direction)
    local hit_props = HitProps.new(
        0,
        Hit.Drag,
        Element.None,
        nil,
        Drag.new(pull_direction, 1)
    )

    from_tile:find_characters(function(entity)
        entity:hit(hit_props)
        return false
    end)
end

---@param tile? Tile
local function pull_adjacent(tile)
    if not tile then
        return
    end

    pull_to_tile(tile, Direction.Up)
    pull_to_tile(tile, Direction.Down)
end

---@param user Entity
function card_init(user)
    local action = Action.new(user, "CHARACTER_SHOOT")
    action:override_animation_frames({ { 1, 16 } })

    local attachment = action:create_attachment("BUSTER")

    local mag_sprite = attachment:sprite()
    mag_sprite:set_layer(-1)
    mag_sprite:set_texture(BUSTER_TEXTURE)
    mag_sprite:use_root_shader()

    local mag_animation = attachment:animation()
    mag_animation:load(BUSTER_ANIMATION_PATH)
    mag_animation:set_state("DEFAULT")
    mag_animation:set_playback(Playback.Loop)

    action.on_execute_func = function()
        Resources.play_audio(SFX)

        local direction = user:facing()
        local target_tile = user:get_tile(direction, 1)

        if not target_tile then
            return
        end

        local coil = Artifact.new()
        coil:set_texture(COIL_TEXTURE)
        coil:set_facing(direction)

        local coil_animation = coil:animation()
        coil_animation:load(COIL_ANIMATION_PATH)
        coil_animation:set_state("DEFAULT")
        coil_animation:set_playback(Playback.Loop)

        local time = 0

        coil.on_update_func = function()
            time = time + 1

            if time >= 60 then
                coil:delete()
            end

            if (time - 2) % 15 ~= 0 then
                return
            end

            pull_adjacent(coil:current_tile())
            pull_adjacent(coil:get_tile(direction, 1))
            pull_adjacent(coil:get_tile(direction, 2))
        end

        Field.spawn(coil, target_tile)
    end

    return action
end
