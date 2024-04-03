function create_soldier_shot(user, props, facing)
    local spell = Spell.new(user:team())
    spell:set_facing(facing)
    spell.slide_started = false
    spell:set_hit_props(
        HitProps.new(
            props.damage,
            Hit.Impact | Hit.Flinch | Hit.Paralyze,
            Element.None,
            user:context(),
            Drag.None
        )
    )
    spell.on_update_func = function(self)
        self:get_tile():attack_entities(self)
        local dest = self:get_tile(self:facing(), 1)
        if not self:is_sliding() then
            if self:current_tile():is_edge() and self.slide_started then
                self:delete()
            end
            local ref = self
            self:slide(dest, 1, function()
                ref.slide_started = true
            end)
        end
    end
    spell.on_collision_func = function(self, other)
        Resources.play_audio(Resources.load_audio("hit.ogg", true))

        local next_tile = self:get_tile(self:facing(), 1)
        if next_tile then
            next_tile:attack_entities(self)
        end
        if not self:deleted() then self:delete() end
    end

    -- I don't think this one runs maybe, but probably doesn't matter
    spell.on_attack_func = function(self, other)
        local next_tile = self:get_tile(self:facing(), 1)
        if next_tile then
            next_tile:attack_entities(self)
        end
        if not self:deleted() then self:delete() end
    end
    spell.can_move_to_func = function(tile)
        return true
    end
    Resources.play_audio(Resources.load_audio("gun.ogg", true))
    return spell
end

function card_init(actor, props)
    local action = Action.new(actor, "PLAYER_IDLE")
    action:set_lockout(make_animation_lockout())
    action.on_execute_func = function(self)
        local user = action:owner()
        local do_once = true
        local facing = Direction.Right
        local start_x = 6
        local increment = -1
        if user:team() == Team.Blue then
            facing = Direction.Left
            start_x = 0
            increment = 1
        end
        local tile_array = {}
        local texture = Resources.load_texture("CommanderAddon.png")
        local anim_path = "CommanderAddon.animation"
        local field = user:field()

        local occupied_query = function(ent)
            return true
        end

        local fail_count = 0

        local function create_soldier(tile)
            local soldier = Spell.new(user:team())
            soldier:set_facing(facing)
            soldier:set_texture(texture)
            local anim = soldier:animation()
            anim:load(anim_path)
            anim:set_state("COMMANDERARMY")
            anim:apply(soldier:sprite())
            anim:on_frame(7, function()
                local spell = create_soldier_shot(user, props, facing)
                field:spawn(spell, soldier:get_tile(soldier:facing(), 1))
            end)
            anim:on_frame(11, function()
                local spell = create_soldier_shot(user, props, facing)
                field:spawn(spell, soldier:get_tile(soldier:facing(), 1))
            end)
            anim:on_frame(15, function()
                local spell = create_soldier_shot(user, props, facing)
                field:spawn(spell, soldier:get_tile(soldier:facing(), 1))
            end)
            anim:on_complete(function()
                soldier:erase()
            end)
            field:spawn(soldier, tile)
        end

        local function create_soldier_wave(list)
            local delay = 9
            local spawn = 1
            local spawned_something = false

            local soldier_handler = user:create_component(Lifetimes.Local)

            soldier_handler.on_update_func = function()
                if delay % 9 == 0 then
                    while (not spawned_something)
                    do
                        if list[spawn] then
                            create_soldier(list[spawn])
                            spawn = spawn + 1
                            spawned_something = true
                        else
                            spawn = spawn + 1
                        end

                        if spawn == 4 then
                            spawned_something = true
                            soldier_handler:eject()
                        end
                    end
                end

                spawned_something = false

                delay = delay + 1
            end
        end

        local colforce_handler = user:create_component(Lifetimes.Battle)

        local delay = 5
        local function tile_checker()
            local done = false

            while (true) do
                -- Collect column
                for i = 1, 3, 1 do
                    tile_array[i] = field:tile_at(start_x, i)
                end

                -- Check which ones can't have a spawn
                -- Probably redundant
                for i = 1, 3, 1 do
                    if tile_array[i]:is_edge() then
                        done = true
                        break
                    end

                    if not tile_array[i]:is_walkable() or user:team() ~= tile_array[i]:team() or #tile_array[i]:find_obstacles(occupied_query) > 0 then
                        tile_array[i] = nil
                        fail_count = fail_count + 1
                    end
                end

                if done then
                    tile_array = {}
                    colforce_handler:eject()
                    break
                end

                -- If we could spawn on some, start the wave
                -- Else, check next column
                if fail_count < 3 and not done then
                    start_x = start_x + increment
                    break
                else
                    fail_count = 0
                    start_x = start_x + increment
                end
            end
        end

        tile_checker()

        colforce_handler.on_update_func = function()
            if delay % 50 == 0 then
                if do_once then
                    do_once = false
                else
                    tile_checker()
                end
                create_soldier_wave(tile_array)
            end
            delay = delay - 1
        end

        action:end_action()
    end

    return action
end
