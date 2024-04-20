local shared_folder_path = "../shared/"

local ParticlePoof = require("BattleNetwork.SmokePoof")

local function reset_attack_variables(self)
    self.should_attack = false
    self.should_move = true
    self.find_target_once = true
    self.move_count = 1
    self.current_move_timer = 0
end

local function vampyric_bite(shademan, anim, target, check_tile)
    shademan.should_attack = false
    shademan.should_move = false
    anim:set_state("VAMP_APPEAR")
    anim:on_complete(function()
        local action = Action.new(shademan, "VAMP_DRAIN")
        local frames = { { 1, 5 }, { 2, 32 }, { 2, 32 }, { 2, 32 }, { 2, 32 }, { 2, 32 } }

        local target_frames = { { 1, 5 }, { 2, 32 }, { 2, 32 }, { 2, 32 }, { 2, 32 } }
        action:override_animation_frames(frames)
        action:set_lockout(make_animation_lockout())

        local target_action = Action.new(target, "PLAYER_HIT")
        target_action:override_animation_frames(target_frames)
        target_action:set_lockout(make_animation_lockout())

        local color_component = shademan:create_component(Lifetimes.Battle)
        color_component.red = 5
        color_component.increment = 5
        color_component.on_update_func = function(self)
            local owner = self:owner()
            if self.red >= 100 then self.increment = -5 end
            if self.red <= 0 then return end
            if self.increment > 0 then
                owner:sprite():set_color_mode(ColorMode.Multiply)
            else
                owner:sprite():set_color_mode(ColorMode.Additive)
            end
            local color_to_add = Color.new(self.red, 0, 0, 255)
            owner:set_color(color_to_add)
            self.red = self.red + self.increment
        end


        action.on_action_end_func = function(self)
            color_component:eject()
            reset_attack_variables(shademan)
        end
        action.on_execute_func = function(self, user)
            self:add_anim_action(2, function()
                if target:get_tile() == check_tile then
                    target:set_health(target:health() - 30)
                    user:set_health(user:health() + 30)
                    target:queue_action(target_action)
                else
                    self:end_action()
                end
            end)
            self:add_anim_action(3, function()
                color_component.red = 5
                color_component.increment = 5
                target:set_health(target:health() - 30)
                user:set_health(user:health() + 30)
            end)
            self:add_anim_action(4, function()
                color_component.red = 5
                color_component.increment = 5
                target:set_health(target:health() - 30)
                user:set_health(user:health() + 30)
            end)
            self:add_anim_action(5, function()
                color_component.red = 5
                color_component.increment = 5
                target:set_health(target:health() - 30)
                user:set_health(user:health() + 30)
            end)
            self:add_anim_action(6, function()
                color_component.red = 5
                color_component.increment = 5
                target:set_health(target:health() - 30)
                user:set_health(user:health() + 30)
            end)
        end
        shademan:queue_action(action)
    end)
end
local function create_noise_crush(shademan)
    local spell = Spell.new(shademan:team())
    spell:set_facing(shademan:facing())
    spell:set_tile_highlight(Highlight.Solid)
    local damage = 40
    local rank = shademan:rank()
    if rank == Rank.EX then damage = 80 elseif rank == Rank.SP then damage = 120 end
    spell:set_hit_props(
        HitProps.new(
            damage,
            Hit.Impact | Hit.PierceInvis,
            Element.None,
            shademan:context(),
            Drag.None
        )
    )
    local do_once = true
    local spell_timer = 999
    local forward_tile = nil
    local up_tile = nil
    local down_tile = nil
    local spawn_timer = 16
    local has_hit = false
    spell.on_update_func = function(self)
        if do_once then
            spell_timer = 48
            do_once = false
            forward_tile = self:get_tile(self:facing(), 1)
            up_tile = forward_tile:get_tile(Direction.Up, 1)
            down_tile = forward_tile:get_tile(Direction.Down, 1)
        end
        if forward_tile and not forward_tile:is_edge() then forward_tile:highlight(Highlight.Solid) end
        if up_tile and not up_tile:is_edge() then up_tile:highlight(Highlight.Solid) end
        if down_tile and not down_tile:is_edge() then down_tile:highlight(Highlight.Solid) end
        if spawn_timer <= 0 then
            self:get_tile():attack_entities(self)
            forward_tile:attack_entities(self)
            up_tile:attack_entities(self)
            down_tile:attack_entities(self)
            if spell_timer <= 0 then
                self:delete()
            else
                spell_timer = spell_timer - 1
            end
        else
            spawn_timer = spawn_timer - 1
        end
    end

    spell.on_attack_func = function(self, other)
        local hitbox = Hitbox.new(self:team())
        local props = HitProps.new(
            0,
            Hit.Impact | Hit.Paralyze,
            Element.None,
            shademan:context(),
            Drag.None
        )
        if other:is_moving() then
            props.flags = props.flags & Hit.Confuse
        else
            props.flags = props.flags & Hit.Paralyze
        end

        hitbox:set_hit_props(props)
        if not shademan:deleted() then shademan:field():spawn(hitbox, other:get_tile()) end
        self:erase()
    end
    return spell
end

local function spawn_bat(shademan)
    local bat = Obstacle.new(shademan:team())
    bat:set_health(10)
    bat:set_facing(shademan:facing())
    local direction = bat:facing()
    bat:set_texture(shademan:texture())
    bat:set_name("Bat")
    local anim = bat:animation()
    anim:copy_from(shademan:animation())
    anim:set_state("BAT")
    anim:apply(bat:sprite())
    anim:set_playback(Playback.Loop)
    local damage = 40
    local rank = shademan:rank()
    if rank == Rank.EX then damage = 80 elseif rank == Rank.SP then damage = 120 end
    bat:set_hit_props(
        HitProps.new(
            damage,
            Hit.Impact | Hit.Flash,
            Element.None,
            shademan:context(),
            Drag.None
        )
    )
    bat:sprite():set_layer(-1)
    bat:enable_sharing_tile(true)
    bat.slide_started = false
    bat.on_collision_func = function(self, other)
        self:delete()
    end
    local field = shademan:field()
    bat.on_delete_func = function(self)
        self:erase()
    end
    local same_column_query = function(c)
        return not c:deleted() and c:team() ~= bat:team() and c:get_tile():x() == bat:get_tile():x() and
            c:get_tile():y() ~= bat:get_tile():y()
    end
    local has_turned = false
    bat.on_update_func = function(self)
        self:get_tile():attack_entities(self)
        self:get_tile():highlight(Highlight.Solid)
        if self:current_tile():is_edge() and self.slide_started and not self:deleted() then
            self:delete()
        end
        if self:deleted() then return end
        if self:is_sliding() == false then
            local dest = self:get_tile(direction, 1)
            if #field:find_characters(same_column_query) > 0 and not has_turned then
                local target = field:find_characters(same_column_query)[1]
                if target:get_tile():y() < self:get_tile():y() then
                    direction = Direction.Up
                else
                    direction = Direction.Down
                end
                dest = self:get_tile(direction, 1)
                has_turned = true
            end
            local ref = self
            self:slide(dest, (24), (0), function()
                ref.slide_started = true
            end)
        end
    end
    bat.can_move_to_func = function(tile)
        return true
    end
    return bat
end

local function do_noise_crush(self, anim)
    local field = self:field()
    local anim = self:animation()
    anim:set_state("WING_OPEN")
    self:set_counterable(true)
    local action = Action.new(self, "WING_LOOP")
    action:override_animation_frames(self.long_frames)
    action:set_lockout(make_animation_lockout())
    self:set_counterable(false)
    action.on_execute_func = function(act, user)
        act.noise_crush = create_noise_crush(self)
        act.noise_fx = Spell.new(self:team())
        act.noise_fx:set_facing(self:facing())
        act.noise_fx:set_texture(self:texture())
        act.noise_fx:sprite():set_layer(-2)
        local noise_fx_anim = act.noise_fx:animation()
        noise_fx_anim:copy_from(self:animation())
        noise_fx_anim:set_state("NOISE_CRUSH")
        noise_fx_anim:apply(act.noise_fx:sprite())
        noise_fx_anim:set_playback(Playback.Loop)
        act:add_anim_action(1, function()
            field:spawn(act.noise_crush, self:get_tile(self:facing(), 1))
        end)
        act:add_anim_action(16, function()
            field:spawn(act.noise_fx, self:get_tile(self:facing(), 1))
        end)
    end
    action.on_action_end_func = function(act)
        if not act.noise_crush:deleted() then act.noise_crush:delete() end
        act.noise_fx:erase()
        anim:set_state("WING_CLOSE")
        anim:on_complete(function()
            anim:set_state("IDLE")
            anim:set_playback(Playback.Loop)
        end)
    end
    self:queue_action(action)
    reset_attack_variables(self)
end

local function do_claw_attack(self, anim)
    local field = self:field()
    local anim = self:animation()
    self:set_counterable(true)
    local action = Action.new(self, "CLAW_ATTACK")
    local spell = Spell.new(self:team())
    action.on_execute_func = function(act, user)
        local spell_tile = self:get_tile(self:facing(), 1)
        local spell_once = true
        spell.on_collision_func = function(self, other)
            self:delete()
        end
        local damage = 90
        local rank = self:rank()
        if rank == Rank.EX then damage = 180 elseif rank == Rank.SP then damage = 200 end
        spell:set_hit_props(
            HitProps.new(
                damage,
                Hit.Impact | Hit.Flash | Hit.Flinch,
                Element.None,
                self:context(),
                Drag.None
            )
        )
        local copytile1 = spell_tile:get_tile(Direction.Up, 1)

        local copytile2 = spell_tile:get_tile(Direction.Down, 1)

        spell.on_update_func = function(self)
            spell_tile:attack_entities(self)
            copytile1:attack_entities(self)
            copytile2:attack_entities(self)
            spell_tile:highlight(Highlight.Flash)
            copytile1:highlight(Highlight.Flash)
            copytile2:highlight(Highlight.Flash)
        end
        act:add_anim_action(2, function()
            field:spawn(spell, spell_tile)
        end)
        act:add_anim_action(3, function()
            self:set_counterable(false)
        end)
        spell.on_delete_func = function(self)
            if self and not self:deleted() then self:erase() end
        end
    end
    action.on_action_end_func = function(act)
        if not spell:deleted() then spell:delete() end
        anim:set_state("IDLE")
        anim:set_playback(Playback.Loop)
    end
    self:queue_action(action)
    reset_attack_variables(self)
end

local function do_bat_attack(self, anim)
    local occupied_query = function(ent)
        if ent:health() <= 0 then return false end
        return Obstacle.from(ent) ~= nil and ent:name() ~= "Bat" or Character.from(ent) ~= nil
    end
    local field = self:field()
    self.anim:set_state("WING_OPEN")
    self.anim:on_complete(function()
        self.anim:set_state("WING_LOOP")
        local tile_direction_list = { Direction.Up, self:facing(), Direction.Down,
            Direction.join(self:facing(), Direction.Up), Direction.join(self:facing(), Direction.Down) }
        local bat_tile = nil
        for i = 1, #tile_direction_list, 1 do
            local prospective_tile = self:get_tile(tile_direction_list[i], 1)
            if prospective_tile and #prospective_tile:find_entities(occupied_query) == 0 and not prospective_tile:is_edge() then
                bat_tile = prospective_tile
                break
            end
        end
        if bat_tile ~= nil then
            local bat = spawn_bat(self)
            local fx = ParticlePoof.new()
            field:spawn(fx, bat_tile)
            field:spawn(bat, bat_tile)
        end
        self.anim:set_state("WING_CLOSE")
        self.anim:on_complete(function()
            self.anim:set_state("IDLE")
            self.anim:set_playback(Playback.Loop)
        end)
    end)
end

local function move_towards_foe(self, target, is_bite, anim)
    local field = self:field()
    local own_tile = self:get_tile()
    local desired_tile = nil
    local target_tile = nil
    local moved = false
    local possible_tiles = {}
    if is_bite then
        local directions = {
            target:facing(), target:facing_away()
        }
        for d = 1, #directions, 1 do
            target_tile = target:get_tile()
            local check_tile = target_tile:get_tile(directions[d], 1)
            if check_tile and self:can_move_to(check_tile) then table.insert(possible_tiles, check_tile) end
        end
    elseif self:is_team(target:get_tile(target:facing(), 1):team()) then
        local directions = {
            Direction.Right, Direction.UpRight, Direction.DownRight,
            Direction.Left, Direction.UpLeft, Direction.DownLeft
        }
        for d = 1, #directions, 1 do
            target_tile = target:get_tile()
            local check_tile = target_tile:get_tile(directions[d], 1)
            if check_tile and self:can_move_to(check_tile) then table.insert(possible_tiles, check_tile) end
        end
    else
        local directions = { Direction.Right, Direction.Left }
        for d = 1, #directions, 1 do
            target_tile = target:get_tile()
            local check_tile = target_tile:get_tile(directions[d], 2)
            if check_tile and self:can_move_to(check_tile) then table.insert(possible_tiles, check_tile) end
        end
    end
    if #possible_tiles > 0 then
        for z = 1, #possible_tiles, 1 do
            if self:can_move_to(possible_tiles[z]) then
                desired_tile = possible_tiles[z]
                break
            end
        end
    end
    if desired_tile ~= nil then
        local state = "WARP_OUT"
        if is_bite then state = "VAMP_VANISH" end
        anim:set_state(state)
        moved = self:teleport(desired_tile, function()
            if is_bite then
                vampyric_bite(self, anim, target, target_tile)
            else
                anim:set_state(state)
                anim:on_complete(function()
                    if desired_tile:team() ~= self:team() then
                        if self:get_tile():x() < target_tile:x() then
                            self:set_facing(Direction.Right)
                        else
                            self:set_facing(Direction.Left)
                        end
                    else
                        self:set_facing(desired_tile:facing())
                    end
                    local distance = math.abs(self:get_tile():x() - target_tile:x())
                    if distance <= 1 then
                        do_claw_attack(self, anim)
                    else
                        do_noise_crush(self, anim)
                    end
                end)
            end
        end)
        if not moved then
            anim:set_state("WARP_IN")
            self.current_move_timer = 0
        end
        return moved
    end
    return moved
end

local function move_at_random(self)
    local field = self:field()
    local moved = false
    local target_tile = nil
    local tile_array = {}
    for x = 1, 6, 1 do
        for y = 1, 3, 1 do
            local prospective_tile = field:tile_at(x, y)
            if prospective_tile and self:can_move_to(prospective_tile) and self:is_team(prospective_tile:team()) then
                table.insert(tile_array, prospective_tile)
            end
        end
    end
    if #tile_array == 0 then return moved end

    target_tile = tile_array[math.random(1, #tile_array)]
    if target_tile then
        self.anim:set_state("WARP_OUT")
        moved = self:teleport(target_tile, function()
            self:set_facing(target_tile:facing())
            self.anim:set_state("WARP_IN")
            self.anim:on_complete(function()
                self.move_count = self.move_count + 1
                self.current_move_timer = 0
                if self.move_count >= self.goal_move_count then
                    self.move_count = 1
                    self.goal_move_count = 3
                    self.should_attack = true
                    self.should_move = false
                end
            end)
        end)
        if not moved then
            self.anim:set_state("WARP_IN")
            self.current_move_timer = 0
        end
    end
    return moved
end

function find_best_target(plane)
    local target = nil
    local field = plane:field()
    local query = function(c)
        return c:team() ~= plane:team()
    end
    local potential_threats = field:find_characters(query)
    local goal_hp = 99999
    if #potential_threats > 0 then
        for i = 1, #potential_threats, 1 do
            local possible_target = potential_threats[i]
            if possible_target:health() <= goal_hp and possible_target:health() > 0 then
                target = possible_target
            end
        end
    end
    return target
end

function character_init(self)
    --meta
    self:set_name("Shademan")
    local rank = self:rank()
    local previous_tile = nil
    local last_attack = nil
    local field = nil

    self:set_texture(Resources.load_texture("shademan.png"))

    self.anim = self:animation()
    self.anim:load("shademan.animation")
    self.anim:set_state("IDLE")
    self.anim:set_playback(Playback.Loop)
    self.anim:apply(self:sprite())

    self:ignore_negative_tile_effects(true)
    self:ignore_hole_tiles(true)

    self.move_count = 1
    self.goal_move_count = 3
    self.teleport_cooldown_list = { 36, 18, 18 }
    self.current_move_timer = 0
    self.find_target_once = true
    self.should_attack = false
    self.should_move = true

    self:register_status_callback(Hit.Flinch, function()
        self.current_move_timer = 0
        self.anim:set_state("OUCH")
        self.anim:on_complete(function()
            self.anim:set_state("IDLE")
            self.anim:set_playback(Playback.Loop)
        end)
    end)
    local frame1 = { 1, 1 }
    self.long_frames =
    {
        frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1,
        frame1, frame1, frame1,
        frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1,
        frame1, frame1, frame1,
        frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1,
        frame1, frame1, frame1,
        frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1, frame1,
        frame1, frame1, frame1
    }

    self.target = nil
    self.tile_table = {}
    self.on_spawn_func = function(self)
        field = self:field()
        for x = 1, 6, 1 do
            for y = 1, 3, 1 do
                local check_tile = field:tile_at(x, y)
                if check_tile and not check_tile:is_edge() and self:is_team(check_tile:team()) then
                    table.insert(
                        self.tile_table, check_tile)
                end
            end
        end
        field = self:field()
        previous_tile = self:get_tile()
        self.target = nil
    end
    self.on_countered_func = function()
        self:set_facing(previous_tile:facing())
        self:teleport(previous_tile, nil)
    end
    local occupied_query = function(ent)
        if ent:health() <= 0 then return false end
        if Obstacle.from(ent) ~= nil then
            if ent:name() == "Bat" then return true end
            return false
        end
        return Character.from(ent) == nil and Player.from(ent) == nil
    end
    self.can_move_to_func = function(tile)
        if not tile then return false end
        if tile:is_edge() then return false end
        return #tile:find_entities(occupied_query) == 0
    end
    self.on_update_func = function(self)
        if self.should_move then
            if self.current_move_timer >= self.teleport_cooldown_list[self.move_count] then
                self.current_move_timer = 0
                if self.move_count < self.goal_move_count then
                    if self.find_target_once then
                        self.target = find_best_target(self)
                        self.find_target_once = false
                    end
                    move_at_random(self)
                else
                    self.move_count = 1
                    self.should_move = false
                    self.should_attack = true
                end
            else
                self.current_move_timer = self.current_move_timer + 1
            end
        elseif self.should_attack then
            if last_attack ~= "Bat Attack" then
                do_bat_attack(self, self.anim)
                last_attack = "Bat Attack"
                reset_attack_variables(self)
            elseif last_attack == "Bat Attack" then
                if rank == Rank.SP and self:health() <= math.floor(health / 2) and math.random(1, 20) > 12 then
                    self.target = find_best_target(self)
                    local moved = move_towards_foe(self, self.target, true, self.anim)
                    if moved then last_attack = "special" else last_attack = "failed" end
                else
                    reset_attack_variables(self)
                    self.target = find_best_target(self)
                    local moved = move_towards_foe(self, self.target, false, self.anim)
                    if moved then last_attack = "regular" else last_attack = "failed" end
                end
            end
        end
    end
end

return character_init