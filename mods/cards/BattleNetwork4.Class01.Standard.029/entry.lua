---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local AUDIO = Resources.load_audio("ElecShock.ogg")
local TEXTURE = Resources.load_texture("bn4_elem_breath_attacks.png")
local BUSTER_TEXTURE = Resources.load_texture("bn4_breath_buster.png")
local firstBlocked = false;
local frame_times = { { 1, 45 } }

function card_init(actor, props)
    local action = Action.new(actor, "CHARACTER_SHOOT")
    action:override_animation_frames(frame_times)
    action:set_lockout(ActionLockout.new_animation())
    action.on_execute_func = function(self, user)
        user:set_counterable(true)
        local buster = self:create_attachment("BUSTER")
        buster:sprite():set_texture(BUSTER_TEXTURE)
        buster:sprite():set_layer(-1)
        buster:sprite():use_root_shader()
        local buster_anim = buster:animation()
        buster_anim:load("bn4_breath_buster.animation")
        buster_anim:set_state("SPAWN_ELEC")

        local tile = user:get_tile(user:facing(), 2)

        local attackTileIndex = 0
        local audioplay = 0
        buster_anim:on_frame(2, function()
            buster_anim:set_state("ATTACK_ELEC")
            buster_anim:set_playback(Playback.Loop)
            user:set_counterable(false)
            local spawn_step = action:create_step()
            local next_spawn = 0
            spawn_step.on_update_func = function()
                if next_spawn > 0 then
                    next_spawn = next_spawn - 1
                    return
                end
                next_spawn = 10

                if attackTileIndex == 0 then
                    create_attack(user, props, user:get_tile(user:facing(), 1), true)
                end

                if attackTileIndex == 1 and firstBlocked == false then
                    create_attack(user, props, tile, false)
                    create_attack(user, props, tile:get_tile(Direction.Up, 1), false)
                    create_attack(user, props, tile:get_tile(Direction.Down, 1), false)
                end



                attackTileIndex = attackTileIndex + 1

                local wait_step = action:create_step()
                local wait_time = 0
                wait_step.on_update_func = function()
                    wait_time = wait_time + 1

                    if wait_time > 10 then
                        wait_step:complete_step()
                    end
                end

                if audioplay <= 2 then
                    Resources.play_audio(AUDIO)
                    audioplay = audioplay + 1
                end
            end
        end)
    end
    return action
end

function create_attack(user, props, spawn_tile, first)
    local timer = false
    local time = 0
    if not spawn_tile then return end

    local spell = Spell.new(user:team())

    if first == true and spawn_tile:is_walkable() == false then
        firstBlocked = true;
        spell:delete()
        return
    else
        firstBlocked = false;
    end

    if first == false and spawn_tile:is_walkable() == false then
        spell:delete()
        return
    end

    local hitter = false

    spell:set_facing(user:facing())
    spell:set_tile_highlight(Highlight.Solid)
    spell:set_texture(TEXTURE)

    local anim = spell:animation()
    anim:load("bn4_elem_breath_attacks.animation")
    anim:set_state("SPAWN_ELEC")
    anim:set_playback(Playback.Loop)
    anim:on_complete(function()
        timer = true
    end)



    local hit_props = HitProps.from_card(
        props,
        user:context(),
        Drag.None
    )



    spell:set_hit_props(hit_props)





    spell.on_update_func = function(self)
        spell:current_tile():set_state(TileState.Cracked)
        if spell:current_tile():is_edge() then self:delete() end
        if not hitter then
            self:current_tile():attack_entities(self)
        end
        if timer == true then
            time = time + 1
        end



        if time == 15 then
            anim:set_state("DESPAWN_ELEC")

            anim:on_complete(function()
                spell:delete()
            end)
        end
    end

    spell.on_collision_func = function(self, other) end

    spell.on_attack_func = function(self, other)
        hitter = true
    end

    spell.on_delete_func = function(self) self:erase() end

    -- Tornado cannot move. It only spawns.
    spell.can_move_to_func = function(tile) return false end

    -- spawn the fire
    Field.spawn(spell, spawn_tile)
end
