local bn_assets = require("BattleNetwork.Assets")

local buster_texture = bn_assets.load_texture("bn4_buster_firearm.png")
local buster_anim_path = bn_assets.fetch_animation_path("bn4_buster_firearm.animation")

local flame_texture = bn_assets.load_texture("bn4_elem_flames.png")
local flame_animation_path = bn_assets.fetch_animation_path("bn4_elem_flames.animation")

local hit_texture = bn_assets.load_texture("bn6_hit_effects.png")
local hit_anim_path = bn_assets.fetch_animation_path("bn6_hit_effects.animation")

local AUDIO = Resources.load_audio("fireburn.ogg")
local BOOSTED_AUDIO = bn_assets.load_audio("panel_change_indicate.ogg")

local function create_flame_spell(user, props, state, effectState, boosted)
    local spell = Spell.new(user:team())
    local hits
    local timer = 0
    local time = 0
    local just_hit = false


    hits = 1

    if boosted then
        hits = 2
    end

    local animation = spell:animation()
    local hit_props = HitProps.from_card(
        props,
        user:context(),
        Drag.None
    )
    spell:set_hit_props(
        hit_props
    )

    spell:set_texture(flame_texture)

    animation:load(flame_animation_path)
    animation:set_state(state)
    animation:set_playback(Playback.Loop)

    spell:set_tile_highlight(Highlight.Solid)

    local sprite = spell:sprite()
    sprite:set_layer(-2)

    animation:apply(sprite)

    spell:set_facing(user:facing())

    spell.has_spawned = false

    spell.on_spawn_func = function(self)
        self.has_spawned = true

        local tile = self:current_tile()

        if not tile:is_walkable() then return end
    end

    spell.on_collision_func = function(self, other)
        local fx = Spell.new(self:team())

        fx:set_texture(hit_texture)

        local anim = fx:animation()

        local fx_sprite = fx:sprite()

        anim:load(hit_anim_path)
        anim:set_state(effectState)

        sprite:set_layer(-3)

        anim:apply(fx_sprite)
        anim:on_complete(function()
            fx:erase()
        end)
        hits = hits - 1
        timer = time + 10
        just_hit = true
        Field.spawn(fx, self:current_tile())
    end


    spell.on_update_func = function(self)
        if boosted and time % 10 == 0 then
            Resources.play_audio(BOOSTED_AUDIO)
        end
        time = time + 1

        if hits == 1 then
            hit_props.flags = hit_props.flags | Hit.Flash
            spell:set_hit_props(hit_props)
        end

        if not just_hit and hits > 0 then
            spell:attack_tile(self:current_tile())
        end

        if just_hit and timer == time then
            just_hit = false
        end
    end


    return spell
end




local function despawn_flame(flame, state)
    -- Do nothing if the flame never appeared.
    if flame._has_spawned ~= true then return end

    -- Change the animation and erase on completion.
    local anim = flame:animation()
    anim:set_playback(Playback.Once)
    anim:set_state(state)
    anim:apply(flame:sprite())
    anim:on_complete(function()
        flame:erase()
    end)
end






function card_init(user, props)
    local action = Action.new(user, "CHARACTER_SHOOT")
    local tile_array = {}
    local boosted_tile_array = {}
    local spells = {}
    local self_tile = user:current_tile()
    local facing = user:facing()

    local states =
    {
        "FIRE",
        "AQUA",
        "WOOD",
        "SAND",
        "DARK"
    }

    local statesDespawn =
    {
        "FIRE_DESPAWN",
        "AQUA_DESPAWN",
        "WOOD_DESPAWN",
        "SAND_DESPAWN",
        "DARK_DESPAWN"
    }

    local hit_effects =
    {
        "FIRE",
        "AQUA",
        "WOOD",
        "PEASHOT",
        "PEASHOT"
    }

    local tile_states =
    {
        TileState.Lava,
        TileState.Ice,
        TileState.Grass,
        TileState.Sand,
        TileState.Poison
    }
    for i = 1, 3, 1 do
        local prospective_tile = self_tile:get_tile(facing, i)
        if prospective_tile and not prospective_tile:is_edge() then
            table.insert(tile_array, prospective_tile)
        end
    end

    for i = 1, Field.width(), 1 do
        local prospective_tile = self_tile:get_tile(facing, i)
        if prospective_tile and not prospective_tile:is_edge() then
            table.insert(boosted_tile_array, prospective_tile)
        end
    end

    local index = 3
    local boosted = false
    local boosted_frame = 20
    local normal_frame = 15


    for _, value in ipairs(props.tags) do
        if value == "ElemFlar" then
            index = 1
        elseif value == "ElemIce" then
            index = 2
        elseif value == "ElemLeaf" then
            index = 3
        elseif value == "ElemSand" then
            index = 4
        elseif value == "ElemDark" then
            index = 5
        end
    end



    if self_tile:state() == tile_states[index] then
        boosted = true
        self_tile:set_state(TileState.Normal)
    end



    local frames = { { 1, 10 }, { 1, 10 }, { 1, 10 }, { 1, 10 } }


    action:override_animation_frames(frames)
    action:set_lockout(ActionLockout.new_animation())
    action.on_execute_func = function(self, user)
        local buster = self:create_attachment("BUSTER")
        local buster_sprite = buster:sprite()
        buster_sprite:set_texture(user:texture())
        buster_sprite:set_layer(-2)
        buster_sprite:use_root_shader()






        buster_sprite:set_texture(buster_texture)
        buster_sprite:set_layer(-2)

        local buster_anim = buster:animation()
        buster_anim:load(buster_anim_path)
        buster_anim:set_state("SPAWN")
        buster_anim:apply(buster_sprite)

        buster_anim:on_complete(function()
            buster_anim:set_state("LOOP")
            buster_anim:set_playback(Playback.Loop)
        end)

        local buster_point = user:animation():get_point("BUSTER")
        local origin = user:sprite():origin()
        local fire_x = buster_point.x - origin.x + 21 - Tile:width()
        local fire_y = buster_point.y - origin.y


        for _, tile in ipairs(boosted_tile_array) do
            self.flame = create_flame_spell(user, props, states[index], hit_effects[index], boosted)
            self.flame:set_offset(fire_x, fire_y)
            spells[#spells + 1] = self.flame
        end
        -- spawn first flame
        if not boosted then
            Resources.play_audio(AUDIO)
        end
        local despawn_index = 1
        local spawn_index = 1
        local despawn_timer = 30
        if #tile_array > 0 or #boosted_tile_array > 0 then
            Field.spawn(spells[spawn_index], tile_array[spawn_index])
            spawn_index = spawn_index + 1
        end

        local time = 0
        local timer = 5

        action.on_update_func = function()
            time = time + 1



            if not boosted then
                for _, tile in ipairs(tile_array) do
                    if time == timer then
                        if #tile_array >= spawn_index then
                            Field.spawn(spells[spawn_index], tile_array[spawn_index])
                            spawn_index = spawn_index + 1
                            timer = timer + 4
                        end
                    end
                    if time >= despawn_timer then
                        if #tile_array >= despawn_index then
                            despawn_flame(spells[despawn_index], statesDespawn[index])
                            despawn_index = despawn_index + 1
                            despawn_timer = despawn_timer + time
                        end
                    end
                end
            end

            if boosted then
                if time == timer then
                    if #boosted_tile_array >= spawn_index then
                        Field.spawn(spells[spawn_index], boosted_tile_array[spawn_index])
                        spawn_index = spawn_index + 1
                        timer = timer + 4
                    end
                end

                if time >= despawn_timer then
                    if #boosted_tile_array >= despawn_index then
                        despawn_flame(spells[despawn_index], statesDespawn[index])
                        despawn_index = despawn_index + 1
                        despawn_timer = despawn_timer + time
                    end
                end
            end
        end

        action.on_action_end_func = function(self)
            for i, spell in ipairs(spells) do
                if not spells[i]:deleted() then spells[i]:erase() end
            end
        end
    end
    return action
end
