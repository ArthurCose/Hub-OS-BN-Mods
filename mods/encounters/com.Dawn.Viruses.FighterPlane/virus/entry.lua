local noop = function() end
local texture = nil
local shot_texture = nil
local shot_animation = nil
local animation_path = nil
local pew = nil

local boom_sound = Resources.load_audio("boom.ogg")
local boom_texture = Resources.load_texture("spell_explosion.png")
local boom_anim = "spell_explosion.animation"

function get_endloop_tile(plane)
    local field = plane:field()
    local y = plane:get_tile():y()
    if plane:rank() ~= Rank.V1 then
        local target = find_best_target(plane)
        if target and not target:deleted() then y = target:get_tile():y() end
    end
    local dest = field:tile_at(7, tonumber(y))
    if plane:facing() == Direction.Right then
        dest = field:tile_at(0, tonumber(y))
    end
    plane._is_looping = true
    return dest
end

function find_best_target(plane)
    local target = nil
    local field = plane:field()
    local query = function(c)
        if c:team() ~= plane:team() then
            if Obstacle.from(c) ~= nil then return false end
            return true
        end
        return false
    end
    local potential_threats = field:find_characters(query)
    local goal_hp = 100
    if #potential_threats > 0 then
        for i = 1, #potential_threats, 1 do
            local possible_target = potential_threats[i]
            if possible_target:health() <= goal_hp then
                target = possible_target
            end
        end
    end
    return target
end

function create_attack(plane)
    local spell = Spell.new(plane:team())
    spell:set_tile_highlight(Highlight.Flash)
    spell:set_hit_props(
        HitProps.new(
            plane._attack,
            Hit.Flinch | Hit.Impact,
            Element.None,
            plane:context(),
            Drag.None
        )
    )
    local do_once = true
    local field = plane:field()
    local flash_before_strike = math.min(10, math.floor(plane._count_between_attack_sends / 2))
    spell.on_update_func = function(self)
        if flash_before_strike <= 0 then
            self:get_tile():attack_entities(self)
            if do_once then
                do_once = false
                local blast_fx = Artifact.new()
                blast_fx:set_texture(shot_texture)
                local blast_anim = blast_fx:animation()
                blast_anim:load(shot_animation)
                blast_anim:set_state("DEFAULT")
                blast_fx:sprite():set_layer(-2)
                blast_anim:on_complete(function()
                    blast_fx:erase()
                    self:erase()
                end)
                field:spawn(blast_fx, self:get_tile())
            end
        else
            flash_before_strike = flash_before_strike - 1
        end
    end
    Resources.play_audio(pew)
    return spell
end

function character_init(plane)
    if not texture then
        texture = Resources.load_texture("FighterPlane.greyscaled.png")
        shot_texture = Resources.load_texture("burst.png")
        shot_animation = "explosion.animation"
        animation_path = "FighterPlane.animation"
        pew = Resources.load_audio("gun.ogg")
    end

    -- private variables
    plane._is_looping = false
    plane._should_shoot = false
    plane._should_move = true
    plane._has_risen = false
    plane._is_attacking = false
    plane._delay_before_move = 0
    plane._target_height = -80
    plane._current_move_delay = 0
    plane._tile_slide_speed = 0
    plane._count_between_attack_sends = 0
    plane._attack = 0
    plane._movement_loops = 2
    plane._count_between_attack_sends = 0
    plane._current_attack_delay = 0
    plane._hover_before_lowering = 30
    plane._obstacle_slide_goal_x = -40
    plane._obstacle_slide_movement_x = -4
    plane._attack_range = {}
    plane._original_tile = nil
    plane._toggle_hitbox = true
    plane._stop_shooting_once = true
    plane._spawned_hitbox = false
    plane._do_once = true
    plane._nm_track_once = true
    plane._nm_divebomb_tile = nil

    -- meta
    plane:set_name("FgtrPlne")
    plane:set_height(45)
    plane:set_texture(texture, true)
    local rank = plane:rank()
    if rank == Rank.V1 then
        plane:set_health(140)
        plane._attack = 20
        plane._delay_before_move = 90
        plane._tile_slide_speed = 30
        plane._count_between_attack_sends = 20
        plane:set_palette(Resources.load_texture("plane_v1.pallet.png"))
    elseif rank == Rank.V2 then
        plane:set_health(180)
        plane._attack = 40
        plane._delay_before_move = 75
        plane._tile_slide_speed = 25
        plane._count_between_attack_sends = 15
        plane:set_palette(Resources.load_texture("plane_v2.pallet.png"))
    elseif rank == Rank.V3 then
        plane:set_health(250)
        plane._attack = 60
        plane._delay_before_move = 60
        plane._tile_slide_speed = 20
        plane._count_between_attack_sends = 10
        plane:set_palette(Resources.load_texture("plane_v3.pallet.png"))
    elseif rank == Rank.SP then
        plane:set_health(310)
        plane._attack = 100
        plane._delay_before_move = 45
        plane._tile_slide_speed = 15
        plane._count_between_attack_sends = 5
        plane:set_palette(Resources.load_texture("plane_sp.pallet.png"))
    elseif rank == Rank.NM then
        plane:set_health(310)
        plane._attack = 100
        plane._delay_before_move = 45
        plane._tile_slide_speed = 15
        plane._count_between_attack_sends = 5
        plane:set_palette(Resources.load_texture("plane_commando.pallet.png"))
    end

    local anim = plane:animation()
    anim:load(animation_path)
    anim:set_state("IDLE")
    -- setup defense rules
    plane:add_aux_prop(StandardEnemyAux.new())

    plane:ignore_negative_tile_effects(true)
    plane:ignore_hole_tiles(true)

    -- setup event handlers
    local can_decrease_attack_count_loop = true
    local j = 1
    local propellor = plane:create_node()
    propellor:set_layer(-1)
    propellor:set_texture(texture)
    propellor:use_root_shader(true)
    propellor:set_palette(plane:palette())

    local propellor_animation = Animation.new(animation_path)
    propellor_animation:set_state("PROPELLOR")
    propellor_animation:apply(propellor)
    propellor_animation:set_playback(Playback.Loop)

    local get_point = plane:animation():get_point("PROPELLOR")
    propellor:set_origin(0 - 12, get_point.y + 16)

    local character_query = function(c)
        return c:team() ~= plane:team()
    end
    local obstacle_query = function(o)
        return true
    end

    plane.on_spawn_func = function(self)
        --shadow
        plane:set_shadow(Resources.load_texture("Plane Shadow.png"))
        plane:show_shadow();
        self._original_tile = self:get_tile()
        if self:facing() == Direction.Right then
            self._obstacle_slide_goal_x = 40
            self._obstacle_slide_movement_x = 4
        end
    end

    plane.can_move_to_func = function(tile)
        return true
    end

    local on_collision_func = function(self, other)
        if Obstacle.from(other) ~= nil then
            local field = self:field()
            if not self:is_sliding() and self:get_tile():is_edge() and not self:is_teleporting() and not self._is_looping then
                local y = self._original_tile:y()
                local dest = field:tile_at(7, tonumber(y))
                if self:facing() == Direction.Right then
                    dest = field:tile_at(0, tonumber(y))
                end
                self:teleport(dest, noop)
            end
        end
    end

    local plane_defense_rule = DefenseRule.new(DefensePriority.Last, DefenseOrder.CollisionOnly)
    plane_defense_rule.filter_func = function(statuses)
        statuses.flags = statuses.flags & ~Hit.Drag
        return statuses
    end

    plane:add_defense_rule(plane_defense_rule)


    plane.on_update_func = function(self)
        if self:deleted() then return end
        propellor_animation:update()
        if self:rank() == Rank.NM and self:health() <= 100 then
            if not self:is_sliding() and self:get_tile():is_edge() and not self:is_teleporting() and not self._is_looping then
                local dest = get_endloop_tile(plane)
                self:teleport(dest, function()
                    self._spawned_hitbox = false
                    self._do_once = true
                end)
            end
            if self:get_tile() ~= self._original_tile and not self:is_sliding() then
                self:slide(self:get_tile(self:facing(), 1), (plane._tile_slide_speed), function()
                    self._spawned_hitbox = false
                    self._do_once = true
                    self._is_looping = false
                end)
            elseif self:get_tile() == self._original_tile and not self:is_sliding() then
                if self._do_once then
                    self._do_once = true
                end
            end
            if not self._has_risen then
                if self:offset().y <= self._target_height then
                    self._has_risen = true
                    anim:set_state('ATTACK')
                    anim:set_playback(Playback.Loop)
                else
                    if self._toggle_hitbox then
                        anim:set_state('ATTACK_AIM')
                        self:enable_hitbox(false)
                        self._toggle_hitbox = false
                    end
                    self:set_offset(0.0 * 0.5, self:offset().y - 4 * 0.5)
                end
            else
                local target = nil
                local target_tile = self._nm_divebomb_tile
                if self._nm_track_once then
                    target = find_best_target(self)
                    self._nm_divebomb_tile = self:get_tile(self:facing(), 3)
                    if target and not target:deleted() then
                        self._nm_divebomb_tile = target:get_tile()
                    end
                    target_tile = self._nm_divebomb_tile
                    self._nm_track_once = false
                end
                local speedy_boy = (math.abs(self._target_height * ((target_tile:x() - self:get_tile():x()) + (target_tile:y() - self:get_tile():y()))) / 60)
                if self:offset().y < 0 then
                    self:set_offset(0.0 * 0.5, self:offset().y + speedy_boy * 0.5)
                end
                if self:get_tile() == target_tile then
                    if self._do_once then
                        local plane_blast = create_attack(self)
                        local field = self:field()
                        local fx = Artifact.new()
                        fx:set_texture(boom_texture, true)
                        local animation = fx:animation()
                        animation:load(boom_anim)
                        animation:set_state("Default")
                        animation:apply(fx:sprite())
                        animation:on_complete(function()
                            fx:erase()
                        end)
                        field:spawn(fx, target_tile)
                        field:spawn(plane_blast, target_tile)
                        self:delete()
                        Resources.play_audio(boom_sound)
                    end
                else
                    self:slide(self._nm_divebomb_tile, (plane._tile_slide_speed), function() self._is_looping = false end)
                end
            end
        else
            if self._current_move_delay <= 0 then
                if self._should_shoot then
                    if self._do_once then
                        self._do_once = false
                        local field = plane:field()
                        plane._attack_range = {}
                        for i = 1, 6, 1 do
                            local tile = field:tile_at(i, 2)
                            local top_tile = field:tile_at(i, 2):get_tile(Direction.Up, 1)
                            local bottom_tile = field:tile_at(i, 2):get_tile(Direction.Down, 1)
                            local team = self:team()
                            if tile and not tile:is_edge() and tile:team() ~= team or top_tile and not top_tile:is_edge() and top_tile:team() ~= team or bottom_tile and not bottom_tile:is_edge() and bottom_tile:team() ~= team then
                                if tile:x() > self:get_tile():x() and self:facing() == Direction.Right or tile:x() < self:get_tile():x() and self:facing() == Direction.Left then
                                    if i % 2 == 0 then
                                        table.insert(plane._attack_range, tile:get_tile(Direction.Up, 1))
                                        table.insert(plane._attack_range, tile)
                                        table.insert(plane._attack_range, tile:get_tile(Direction.Down, 1))
                                    else
                                        table.insert(plane._attack_range, tile:get_tile(Direction.Down, 1))
                                        table.insert(plane._attack_range, tile)
                                        table.insert(plane._attack_range, tile:get_tile(Direction.Up, 1))
                                    end
                                end
                            end
                        end
                        if self:rank() == Rank.NM then
                            local n = #self._attack_range
                            for m = n, 1, -1 do
                                table.insert(self._attack_range, self._attack_range[m])
                            end
                        end
                        if plane:facing() == Direction.Right then
                            j = 1
                        else
                            j = #plane._attack_range
                        end
                    end
                    if self:rank() == Rank.V1 and not self._has_risen then
                        self._has_risen = true
                        anim:set_state('ATTACK')
                        anim:set_playback(Playback.Loop)
                    end
                    if not self._has_risen then
                        if self:offset().y <= self._target_height then
                            self._has_risen = true
                            anim:set_state('ATTACK')
                            anim:set_playback(Playback.Loop)
                        else
                            if self._toggle_hitbox then
                                anim:set_state('ATTACK_AIM')
                                self:enable_hitbox(false)
                                self._toggle_hitbox = false
                            end
                            self:set_offset(0.0 * 0.5, self:offset().y - 2 * 0.5)
                        end
                    else
                        local field = self:field()
                        if j == #self._attack_range and plane:facing() == Direction.Right or j == 0 and self:facing() == Direction.Left then
                            if self._stop_shooting_once then
                                self._stop_shooting_once = false
                                anim:set_state('ATTACK_AIM')
                                anim:set_playback(Playback.Reverse)
                                anim:on_complete(function()
                                    anim:set_state('IDLE')
                                    anim:set_playback(Playback.Loop)
                                end)
                            end
                            if self._hover_before_lowering <= 0 then
                                if self:offset().y < 0 then
                                    self:set_offset(0.0 * 0.5, self:offset().y + 2 * 0.5)
                                else
                                    self:enable_hitbox(true)
                                    self._toggle_hitbox = true
                                    self._should_shoot = false
                                    self._should_move = true
                                    self._hover_before_lowering = 30
                                    self._has_risen = false
                                    self._current_attack_delay = self._count_between_attack_sends
                                    self._current_move_delay = self._delay_before_move
                                end
                            else
                                self._hover_before_lowering = self._hover_before_lowering - 1
                            end
                        else
                            if self._current_attack_delay <= 0 then
                                local plane_blast = create_attack(self)
                                field:spawn(plane_blast, self._attack_range[j])
                                self._current_attack_delay = self._count_between_attack_sends
                                if self:facing() == Direction.Right then
                                    j = j + 1
                                else
                                    j = j - 1
                                end
                            else
                                self._current_attack_delay = self._current_attack_delay - 1
                            end
                        end
                    end
                elseif self._should_move then
                    if #self:get_tile():find_characters(character_query) > 0 and not self._spawned_hitbox then
                        local hitbox = Hitbox.new(self:team())
                        hitbox:set_hit_props(
                            HitProps.new(
                                50,
                                Hit.Flinch | Hit.Impact | Hit.Flash,
                                Element.None,
                                plane:context(),
                                Drag.None
                            )
                        )
                        self:field():spawn(hitbox, self:get_tile())
                        self._spawned_hitbox = true
                    end
                    if self._movement_loops > 0 then
                        if not self:is_sliding() and self:get_tile():is_edge() and not self:is_teleporting() and not self._is_looping then
                            local dest = get_endloop_tile(plane)
                            self:teleport(dest, function() plane._movement_loops = plane._movement_loops - 1 end)
                        else
                            local dest = self:get_tile(self:facing(), 1)
                            if dest and #dest:find_obstacles(obstacle_query) > 0 and not self:is_sliding() and not self:is_teleporting() then
                                dest = get_endloop_tile(plane)
                                if self:offset().x ~= self._obstacle_slide_goal_x then
                                    self:set_offset(
                                        self:offset().x + self._obstacle_slide_goal_x / self._tile_slide_speed * 0.5,
                                        0.0 * 0.5)
                                else
                                    self:teleport(dest, function()
                                        self:set_offset(0.0 * 0.5, 0.0 * 0.5)
                                        self._movement_loops = 0
                                        self._spawned_hitbox = false
                                    end)
                                end
                            else
                                self:slide(self:get_tile(self:facing(), 1), (plane._tile_slide_speed), function()
                                    self._is_looping = false
                                    self._spawned_hitbox = false
                                end)
                            end
                        end
                    else
                        if not self:is_sliding() and self:get_tile():is_edge() and not self:is_teleporting() and not self._is_looping then
                            local dest = get_endloop_tile(plane)
                            self:teleport(dest, function() self._spawned_hitbox = false end)
                        end
                        if self:get_tile() ~= self._original_tile then
                            self:slide(self:get_tile(self:facing(), 1), (plane._tile_slide_speed), function()
                                self._is_looping = false
                                self._spawned_hitbox = false
                            end)
                        else
                            self._should_move = false
                            self._should_shoot = true
                            self._has_risen = false
                            self._stop_shooting_once = true
                            self._movement_loops = 2
                            self._do_once = true
                        end
                    end
                end
            else
                self._current_move_delay = self._current_move_delay - 1
            end
        end
    end
    plane.on_battle_start_func = noop
    plane.on_battle_end_func = noop
    plane.on_delete_func = function(self)
        self:default_character_delete()
    end
end
