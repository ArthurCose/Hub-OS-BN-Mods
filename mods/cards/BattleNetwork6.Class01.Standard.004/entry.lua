local bn_helpers = require("BattleNetwork.Assets")

local BUSTER_TEXTURE = bn_helpers.load_texture("airshot.png")
local BUSTER_ANIMATION_PATH = bn_helpers.fetch_animation_path("airshot.animation")
local SHOOT_SFX = bn_helpers.load_audio("spreader.ogg")

function card_init(actor, props)
    local action = Action.new(actor, "CHARACTER_SHOOT")
    action:set_card_properties(props)
    action:override_animation_frames({ { 1, 4 }, { 2, 2 }, { 3, 16 } })

    local original_offset

    action.on_execute_func = function(self, user)
        -- obtain direction user is facing to not call this more than once
        local facing = user:facing()

        -- action starts, enable countering
        user:set_counterable(true)

        -- create airshot arm attachment
        local buster = self:create_attachment("BUSTER")

        -- obtain the sprite so we don't have to call it more than once
        local buster_sprite = buster:sprite()

        -- Set the texture
        buster_sprite:set_texture(BUSTER_TEXTURE)
        buster_sprite:set_layer(-1)
        buster_sprite:use_root_shader()

        -- Create airshot arm attachment animation
        local buster_anim = buster:animation()
        buster_anim:load(BUSTER_ANIMATION_PATH)

        -- set animation state
        buster_anim:set_state("DEFAULT")

        self:on_anim_frame(2, function()
            -- attack starts, can no longer counter
            user:set_counterable(false)

            -- create the attack itself
            local airshot = create_attack(user, props, user:context(), facing)

            -- obtain tile to spawn the attack on and spawn it using the field
            local tile = user:current_tile()
            Field.spawn(airshot, tile)

            -- play a sound to indicate the attack.
            Resources.play_audio(SHOOT_SFX)
        end)

        -- handle offset animation
        original_offset = actor:offset()

        local offset_sign = -1
        if facing == Direction.Left then offset_sign = 1 end
        -- [duration, offset_x][]
        local offsets = {
            { 4,  0 },
            { 0,  offset_sign * 4 },
            { 0,  offset_sign * 5 },
            { 0,  offset_sign * 6 },
            { 99, offset_sign * 7 },
        }

        local offset_elapsed = 0
        local offset_frame = 1

        action.on_update_func = function()
            local current_frame = offsets[offset_frame]

            if offset_elapsed >= current_frame[1] then
                offset_frame = offset_frame + 1
                current_frame = offsets[offset_frame]
                offset_elapsed = 0
            end

            offset_elapsed = offset_elapsed + 1

            actor:set_offset(original_offset.x + current_frame[2], original_offset.y)
        end
    end


    action.on_action_end_func = function()
        if original_offset then
            actor:set_offset(original_offset.x, original_offset.y)
        end

        actor:set_counterable(false)
    end


    return action
end

function create_attack(user, props, context, facing)
    local spell = Spell.new(user:team())
    spell:set_facing(facing)
    spell:set_hit_props(
        HitProps.from_card(
            props,
            context,
            Drag.new(facing, 1)
        )
    )
    -- store starting tile as the user's own tile
    local tile = user:get_tile()

    -- this will be used to teleport 1 frame in.
    local first_move = false

    -- Count times it teleported.
    local move_count = 0

    -- the wait is to make the spell count how many frames it waited without moving
    local wait = 0

    -- Spell cycles this every frame.
    spell.on_update_func = function(self)
        -- If the current tile is an edge tile, immediately remove the spell
        if tile:is_edge() then
            self:erase()
        end

        -- Remember your ABCs: Always Be Casting.
        -- Most attacks try to land a hit every frame!
        tile:attack_entities(self)

        -- Perform first movement
        if first_move == false then
            local dest = self:get_tile(facing, 1)
            self:teleport(dest, function()
                move_count = move_count + 1
                tile = dest
                if move_count == 2 then
                    first_move = true
                end
            end)
        else
            -- Begin counting up the wait timer
            wait = wait + 1

            -- When it hits 2, teleport it.
            if wait == 2 then
                -- Obtain a destination tile
                local dest = self:get_tile(facing, 1)

                -- Initiate teleport
                self:teleport(dest, function()
                    -- Set current tile property and reset wait timer
                    tile = dest
                    wait = 0
                end)
            end
        end
    end

    -- Upon hitting anything, delete self
    spell.on_collision_func = function(self, other)
        -- delete the spell
        self:delete()
    end

    -- No specialty on actually dealing damage, but left in as reference
    -- "Other" is the entity hit by the attack
    spell.on_attack_func = function(self, other)
    end

    -- On delete, simply remove the spell.
    spell.on_delete_func = function(self)
        self:erase()
    end

    -- return the attack we created for spawning.
    return spell
end
