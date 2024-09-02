local reverse_vulcan_spawn_sound = Resources.load_audio("sounds/reverse vulcan spawn.ogg")
local omega_rocket_spawn_sound = Resources.load_audio("sounds/rocket spawn.ogg")
local devil_arm_sound_upper = Resources.load_audio("sounds/devil arm 1.ogg")
local devil_arm_sound_lower = Resources.load_audio("sounds/devil arm 2.ogg")
local red_eye_charge_sound = Resources.load_audio("sounds/red eye charging.ogg")
local red_eye_laser_sound = Resources.load_audio("sounds/red eye laser.ogg")
local alpha_blast_sound = Resources.load_audio("sounds/alphablast.ogg")
local arm_sigma_sound = Resources.load_audio("sounds/arm sigma.ogg")
local crack_sound = Resources.load_audio("sounds/crack.ogg")
local tink_sound = Resources.load_audio("sounds/tink.ogg")
local dash_sound = Resources.load_audio("sounds/dash.ogg")
local gun_audio = Resources.load_audio("sounds/gun.ogg")

local rocket_explosion_texture = Resources.load_texture("rocket explosion.png")
local red_eye_delete_texture = Resources.load_texture("red_eyes_delete.png")
local TEXTURE_FLASHLIGHT = Resources.load_texture("flashlight.png")
local guard_hit_texture = Resources.load_texture("guard_hit.png")
local upper_arm_texture = Resources.load_texture("arm_upper.png")
local lower_arm_texture = Resources.load_texture("arm_lower.png")
local mob_move_texture = Resources.load_texture("mob_move.png")
local red_eye_texture = Resources.load_texture("red_eyes_delete_projectile.png")
local vulcan_texture = Resources.load_texture("vulcan_fx.png")
local rocket_texture = Resources.load_texture("alpha rocket.png")
local taser_texture = Resources.load_texture("alpha taser.png")
local pool_texture = Resources.load_texture("pool.png")
local core_texture = Resources.load_texture("alpha_core.png")

local obstacle_query = function(o)
    return o:health() > 0
end

local function end_alpha_arm(alpha)
    alpha.cooldown = 120
    alpha.is_acting = false
    alpha.goop_health = 40
    alpha.anim_once = true
    alpha.sigma_index = 1
    alpha.omega_attack = false
    alpha.is_vulnerable = false
    alpha.pattern_index = alpha.pattern_index + 1
    if alpha.pattern_index > #alpha.pattern then alpha.pattern_index = 1 end
    alpha.alpha_arm_index = alpha.alpha_arm_index + 1
    if alpha.alpha_arm_index > #alpha.alpha_arm_type then alpha.alpha_arm_index = 1 end
    alpha.upper_arm:reveal()
    alpha.lower_arm:reveal()
    alpha.upper_arm:enable_hitbox(true)
    alpha.lower_arm:enable_hitbox(true)
end

local function drop_trace_fx(target_artifact, lifetimems, desired_color)
    --drop an afterimage artifact mimicking the appearance of an existing spell/artifact/character and fade it out over it's lifetimems
    local fx = Spell.new(target_artifact:team())
    local anim = target_artifact:animation()
    local field = target_artifact:field()
    local offset = target_artifact:offset()
    local texture = target_artifact:texture()
    local elevation = target_artifact:elevation()
    fx:set_facing(target_artifact:facing())
    fx:set_texture(texture, true)

    local fx_animation = fx:animation()
    fx_animation:copy_from(anim)
    fx_animation:set_state(anim:state())
    fx:set_offset(offset.x * 0.5, offset.y * 0.5)
    fx:set_elevation(elevation)

    fx.starting_lifetimems = lifetimems
    fx.lifetimems = lifetimems
    fx.on_update_func = function(self)
        self.lifetimems = math.max(0, self.lifetimems - math.floor((1 / 60) * 1000))
        local alpha = math.floor((fx.lifetimems / fx.starting_lifetimems) * 255)
        self:sprite():set_color_mode(ColorMode.Multiply)
        self:set_color(Color.new(desired_color[1], desired_color[2], desired_color[3], alpha))
        if self.lifetimems == 0 then
            self:erase()
        end
    end

    local tile = target_artifact:current_tile()
    field:spawn(fx, tile:x(), tile:y())
    return fx
end

local function create_claw_defense(spell)
    local defense = DefenseRule.new(DefensePriority.Last, DefenseOrder.Always)
    defense.texture = guard_hit_texture
    defense.animation = "guard_hit.animation"
    defense.audio = tink_sound
    defense.defense_func = function(defense, attacker, defender)
        defense:block_damage()
        defense:block_impact()
        local artifact = Spell.new(spell:team())
        artifact:set_texture(defense.texture)
        local anim = artifact:animation()
        anim:load(defense.animation)
        anim:set_state("DEFAULT")
        anim:apply(artifact:sprite())
        anim:on_complete(function()
            artifact:erase()
        end)
        defender:field():spawn(artifact, defender:current_tile())
        Resources.play_audio(defense.audio, AudioBehavior.NoOverlap)
    end
    return defense
end

local function find_best_target(alpha)
    local target = nil
    local field = alpha:field()
    local query = function(c)
        return c:team() ~= alpha:team()
    end
    local potential_threats = field:find_characters(query)
    local goal_hp = 0
    if #potential_threats > 0 then
        for i = 1, #potential_threats, 1 do
            local possible_target = potential_threats[i]
            if possible_target and not possible_target:deleted() and possible_target:health() >= goal_hp then
                target = possible_target
            end
        end
    end
    return target
end

local function create_mob_move(texture, state)
    local artifact = Spell.new(Team.Blue)
    artifact:set_texture(texture)
    local anim = artifact:animation()
    anim:load("mob_move.animation")
    anim:set_state(state) --Set the state
    anim:apply(artifact:sprite())
    anim:on_complete(function()
        artifact:erase() --Delete the artifact when the animation completes
    end)
    return artifact
end

local function create_red_eye_arrow(alpha, props, state, direction)
    local spell = Spell.new(alpha:team())
    local texture = red_eye_texture
    local animation = "red_eyes_delete_projectile.animation"
    spell:set_hit_props(props)
    spell:set_texture(texture)
    spell:set_facing(alpha:facing())
    local anim = spell:animation()
    anim:load(animation)
    anim:set_state(state)
    spell:sprite():set_layer(-2) --set_layer determines the order sprites visually draw in.
    anim:apply(spell:sprite())
    spell.slide_started = false
    spell.on_update_func = function(self)
        if self:deleted() then return end
        local tile = self:current_tile()
        if tile:is_edge() and self.slide_started then self:delete() end
        tile:attack_entities(self)
        local dest = self:get_tile(direction, 1)
        local ref = self
        if dest and #dest:find_obstacles(obstacle_query) > 0 then self:delete() end
        self:slide(dest, 7, function()
            ref.slide_started = true
            tile:attack_entities(self)
        end)
    end
    spell.can_move_to_func = function(tile)
        return true
    end
    return spell
end

local function create_sigma_taser(alpha)
    local spell = Spell.new(alpha:team())
    spell:set_texture(taser_texture)
    spell:set_facing(alpha:facing())
    spell:sprite():set_layer(-4)
    local damage = 60
    if alpha:rank() == Rank.SP then damage = 200 end
    spell:set_hit_props(
        HitProps.new(
            damage,
            Hit.Impact | Hit.Flinch | Hit.Flash,
            Element.None,
            alpha:context(),
            Drag.None
        )
    )
    local anim = spell:animation()
    anim:load("alpha taser.animation")
    anim:set_state(alpha.sigma_state[alpha.sigma_index])
    anim:apply(spell:sprite())
    anim:on_complete(function()
        anim:set_state(alpha.sigma_state[alpha.sigma_index])
        anim:apply(spell:sprite())
        alpha.sigma_index = alpha.sigma_index + 1
        alpha.sigma_count = alpha.sigma_count + 1
        if alpha.sigma_index > #alpha.sigma_state then alpha.sigma_index = 1 end
        spell.anim_once = true
    end)
    local field = alpha:field()
    local facing = alpha:facing()
    local center_tile = alpha:get_tile(facing, 2)
    local upper_tile = center_tile:get_tile(Direction.Up, 1)
    local lower_tile = center_tile:get_tile(Direction.Down, 1)
    local center_table = { center_tile }
    local up_down_table = { center_tile }
    for x = 0, 6, 1 do
        local prospective_addition = upper_tile:get_tile(facing, x)
        if prospective_addition and not prospective_addition:is_edge() then
            table.insert(up_down_table,
                prospective_addition)
        end
        prospective_addition = lower_tile:get_tile(facing, x)
        if prospective_addition and not prospective_addition:is_edge() then
            table.insert(up_down_table,
                prospective_addition)
        end
        prospective_addition = center_tile:get_tile(facing, x)
        if prospective_addition and not prospective_addition:is_edge() then
            table.insert(center_table,
                prospective_addition)
        end
    end
    local tile_array = { center_table, up_down_table }
    spell.on_spawn_func = function(self)
        for i = 1, #tile_array[alpha.sigma_index], 1 do
            local check_tile = tile_array[alpha.sigma_index][i]
            if check_tile and not check_tile:is_edge() then
                local hitbox = Spell.new(self:team())
                hitbox:set_hit_props(self:copy_hit_props())
                hitbox.on_update_func = function(self)
                    self:current_tile():attack_entities(self)
                    self:erase()
                end
                field:spawn(hitbox, check_tile)
            end
        end
    end
    spell.can_move_to_func = function(tile) return true end
    spell.anim_once = false
    spell.arm_sound = arm_sigma_sound
    spell.on_update_func = function(self)
        if self.anim_once then
            self.anim_once = false
            Resources.play_audio(self.arm_sound)
            anim:on_complete(function()
                alpha.sigma_count = alpha.sigma_count + 1
                if alpha.sigma_count >= 16 then
                    alpha.is_acting = false
                    self:erase()
                else
                    local tile = self:current_tile()
                    for i = 1, #tile_array[alpha.sigma_index], 1 do
                        local hitbox = Spell.new(self:team())
                        hitbox:set_hit_props(self:copy_hit_props())
                        hitbox.on_update_func = function(self)
                            self:current_tile():attack_entities(self)
                            self:erase()
                        end
                        field:spawn(hitbox, tile_array[alpha.sigma_index][i])
                    end
                    anim:set_state(alpha.sigma_state[alpha.sigma_index])
                    anim:apply(spell:sprite())
                    alpha.sigma_index = alpha.sigma_index + 1
                    if alpha.sigma_index > #alpha.sigma_state then alpha.sigma_index = 1 end
                    spell.anim_once = true
                end
            end)
        end
    end
    return spell
end

local function create_omega_rocket(alpha)
    local spell = Spell.new(alpha:team())
    spell:set_texture(rocket_texture)
    spell:set_facing(alpha:facing())
    spell:sprite():set_layer(-4)
    local damage = 100
    if alpha:rank() == Rank.SP then damage = 300 end
    spell:set_hit_props(
        HitProps.new(
            damage,
            Hit.Impact | Hit.Flinch | Hit.Flash,
            Element.None,
            alpha:context(),
            Drag.None
        )
    )
    local anim = spell:animation()
    anim:load("alpha rocket.animation")
    anim:set_state("IDLE")
    anim:apply(spell:sprite())
    anim:on_complete(function()
        Resources.play_audio(dash_sound)
        anim:set_state("TAKEOFF")
        anim:apply(spell:sprite())
    end)
    spell.slide_started = false
    spell.has_exploded = false
    spell.can_move_to_func = function(tile) return true end
    local ANIMPATH_FLASHLIGHT = "flashlight.animation"
    local field = alpha:field()
    local explosion = rocket_explosion_texture
    local function run_explosion(hitter, array)
        Resources.play_audio(alpha_blast_sound)
        local flashlight = Spell.new(spell:team())
        flashlight:set_facing(Direction.Right)
        local flashlight_anim = flashlight:animation()
        flashlight:set_texture(TEXTURE_FLASHLIGHT, true)
        flashlight:sprite():set_layer(10)
        flashlight_anim:load(ANIMPATH_FLASHLIGHT)
        flashlight_anim:set_state("DEFAULT")
        flashlight_anim:apply(flashlight:sprite())
        flashlight_anim:on_complete(function()
            flashlight:erase()
        end)
        for i = 1, #array, 1 do
            local attack = Spell.new(hitter:team())
            attack:set_hit_props(hitter:copy_hit_props())
            attack:set_texture(explosion)
            attack:sprite():set_layer(-2)
            local anim2 = attack:animation()
            anim2:load("rocket explosion.animation")
            anim2:set_state("0")
            anim2:apply(attack:sprite())
            anim2:on_complete(function()
                attack:erase()
            end)
            attack.on_update_func = function(self)
                self:current_tile():attack_entities(self)
            end
            field:spawn(attack, array[i])
        end
        field:spawn(flashlight, 1, 1)
        hitter:field():shake(15, 60)
    end
    spell.on_collision_func = function(self, other)
    end
    spell.back_boom_array = { field:tile_at(1, 1), field:tile_at(1, 2), field:tile_at(1, 3), field:tile_at(2, 1),
        field:tile_at(2, 2), field:tile_at(2, 3) }
    spell.on_delete_func = function(self)
        if not self.has_exploded then
            run_explosion(self, self.back_boom_array)
            self.has_exploded = true
            alpha.is_acting = false
            self:erase()
        end
    end
    local direction = spell:facing()
    spell.on_update_func = function(self)
        if anim:state() ~= "TAKEOFF" then return end
        if self:deleted() then return end
        local tile = self:current_tile()
        local dest = self:get_tile(direction, 1)
        tile:attack_entities(self)
        if dest and not dest:is_edge() then
            dest:attack_entities(self)
        end
        if not self:is_sliding() then
            if tile:is_edge() and self.slide_started then self:delete() end
            local ref = self
            self:slide(dest, 6, function()
                ref.slide_started = true
            end)
        end
    end
    return spell
end

local function take_alpha_arm_action(alpha, current_arm)
    alpha.is_acting = true
    alpha.is_vulnerable = false
    local field = alpha:field()
    if current_arm == "SIGMA" then
        local spell = create_sigma_taser(alpha)
        field:spawn(spell, alpha:get_tile(alpha:facing(), 2))
        return spell
    elseif current_arm == "OMEGA" then
        local spell = create_omega_rocket(alpha)
        field:spawn(spell, alpha:get_tile(alpha:facing(), 1))
        return spell
    else
        alpha.is_acting = false
    end
end

local function take_red_eye_action(alpha, state)
    alpha.is_acting = true --Set to acting so we don't spam lasers.
    local field = alpha:field()
    local first_tile = alpha:get_tile(alpha:facing(), 2)
    local tile_array = { first_tile, first_tile:get_tile(Direction.Up, 1), first_tile:get_tile(alpha:facing(), 1),
        first_tile:get_tile(Direction.Down, 1) }
    local artifact = Spell.new(alpha:team())
    artifact:set_texture(red_eye_delete_texture)
    artifact:sprite():set_layer(-4)
    local anim = artifact:animation()
    anim:load("red_eyes_delete.animation")
    anim:set_state(state) --Set the state
    anim:apply(artifact:sprite())
    local damage = 80
    if alpha:rank() == Rank.SP then damage = 200 end
    local props = HitProps.new(
        damage,
        Hit.Impact | Hit.Flinch | Hit.Flash,
        Element.None,
        alpha:context(),
        Drag.None
    )
    anim:on_complete(function()
        local state = anim:state()
        if state == "ATTACK_CHARGE" then
            anim:set_state("ATTACK_FIRE")
            Resources.play_audio(red_eye_laser_sound)
            anim:on_complete(function()
                anim:set_state("ATTACK_LAND")
                local hitbox = Spell.new(alpha:team())
                hitbox:set_hit_props(props)
                hitbox.on_update_func = function(self)
                    self:current_tile():attack_entities(self)
                    self:erase()
                end
                field:spawn(hitbox, tile_array[2])
                anim:on_complete(function()
                    anim:set_state("ATTACK_DISSIPATE")
                    anim:on_complete(function()
                        artifact:delete()
                        alpha.is_acting = false
                        alpha.cooldown = 40
                    end)
                end)
                --If the landing tile of Red Eye Delete isn't broken, Crack/Break the tiles.
                --Do this by scanning the compiled tiles above for Cracked state and breaking them if Cracked.
                --If NOT Cracked, then Crack them.
                if tile_array[1]:state() ~= TileState.Broken then
                    Resources.play_audio(crack_sound)
                    alpha:field():shake(8, 60)
                    for i = 1, #tile_array, 1 do
                        if tile_array[i]:state() == TileState.Cracked then
                            tile_array[i]:set_state(TileState.Broken)
                        else
                            tile_array[i]:set_state(TileState.Cracked)
                        end
                    end
                    local up = create_red_eye_arrow(alpha, props, "UP", Direction.Up)
                    local forward = create_red_eye_arrow(alpha, props, "FORWARD", alpha:facing())
                    local down = create_red_eye_arrow(alpha, props, "DOWN", Direction.Down)
                    local check_up = tile_array[2]
                    if check_up and not check_up:is_edge() then
                        field:spawn(up, check_up)
                    end
                    field:spawn(forward, tile_array[3])
                    local check_down = tile_array[4]
                    if check_down and not check_down:is_edge() then
                        field:spawn(down, check_down)
                    end
                end
            end)
        end
    end)
    Resources.play_audio(red_eye_charge_sound)
    field:spawn(artifact, alpha:current_tile())
end

local function create_reverse_vulcan_shot(alpha, texture, props)
    local shot = Spell.new(alpha:team())
    shot:set_tile_highlight(Highlight.Solid)
    shot:set_hit_props(props)
    shot:set_facing(alpha:facing())
    shot:sprite():set_layer(-4)
    shot:set_texture(texture)
    local anim = shot:animation()
    anim:load("vulcan_fx.animation")
    anim:set_state("TILE_BURST")
    anim:apply(shot:sprite())
    anim:on_complete(function()
        alpha.vulcan_shots = alpha.vulcan_shots + 1
        alpha.is_acting = false
    end)
    shot.delay = 15
    shot.on_update_func = function(self)
        if self.delay <= 0 then
            local tile = self:current_tile()
            if tile:is_walkable() then
                tile:attack_entities(self)
            end
            self:erase()
        else
            self.delay = self.delay - 1
        end
    end
    shot.can_move_to_func = function(tile)
        return true
    end
    return shot
end

local function create_reverse_vulcan_flare(alpha, texture)
    local artifact = Spell.new(Team.Blue)
    artifact:set_texture(texture)
    artifact:sprite():set_layer(-4)
    local anim2 = artifact:animation()
    anim2:load("vulcan_fx.animation")
    anim2:set_state("CANNON_BURST")

    anim2:set_playback(Playback.Loop)
    artifact.on_update_func = function(self)
        if alpha.vulcan_shots >= 16 then
            alpha.anim_once = true
            self:erase()
        end
    end
    return artifact
end

local function take_reverse_vulcan_action(alpha)
    alpha.is_acting = true --Set Alpha to be acting so we don't spam shots. Well, any more than we should.
    local texture = alpha.vulcan_texture
    local damage = 20
    if alpha:rank() == Rank.SP then damage = 50 end
    local props = HitProps.new(
        damage,
        Hit.Impact,
        Element.None,
        alpha:context(),
        Drag.None
    )
    local shot = create_reverse_vulcan_shot(alpha, texture, props)
    local target = find_best_target(alpha)
    local field = alpha:field()
    if target and not target:deleted() then
        field:spawn(shot, target:current_tile())
        Resources.play_audio(gun_audio)
    else
        alpha.is_acting = false
    end
end

local function create_devil_hand(alpha, props, texture_part, is_omega)
    local spell = Obstacle.new(alpha:team()) --Create the spell.
    local arm = alpha.upper_arm
    local field = alpha:field()
    local sound = devil_arm_sound_upper
    local direction = Direction.Down
    local target_anim = "arm_upper.animation"
    if texture_part == "arm_lower" then
        sound = devil_arm_sound_lower
        direction = alpha:facing()
        arm = alpha.lower_arm
        target_anim = "arm_lower.animation"
    else
        spell:set_offset(0.0 * 0.5, -40.0 * 0.5)
    end
    local state = "ATTACK"
    if is_omega then state = "ATTACK_OMEGA" end
    spell:set_health(99999)
    spell:set_hit_props(props)
    spell:add_aux_prop(StandardEnemyAux.new())
    spell.spell_defense = create_claw_defense(spell)
    spell:add_defense_rule(spell.spell_defense)
    spell:set_facing(alpha:facing()) --Make sure it's going to face the right way. It's going to be on the "enemy" side compared to the virus.
    spell:set_texture(arm:texture()) --Copying the texture of the arm.
    spell:sprite():set_layer(-4)     --Needs to spawn "over" the player it's attacking.
    local spell_animation = spell:animation()
    spell_animation:load(target_anim)
    spell_animation:set_state(state) --Set the state to attack instead of idle.

    spell.slide_started = false
    spell.cooldown = 20 --Wait for 20 frames before moving to attack.
    spell.spawned_other_claw = false
    spell.play_sound = true
    local negative_tile_array = { TileState.Poison, TileState.Ice, TileState.Cracked, TileState.Lava }
    local rng = math.random(1, #negative_tile_array)
    spell.obstacle_hit = false
    spell.on_update_func = function(self)
        if self:deleted() then return end
        if self.cooldown <= 0 then
            if self.play_sound then
                Resources.play_audio(sound)
                self.play_sound = false
            end
            local tile = self:current_tile()
            if texture_part == "arm_upper" and tile:y() == 2 then alpha.is_acting = false end
            if is_omega and texture_part == "arm_upper" and not tile:is_edge() and self:is_team(tile:get_tile(self:facing_away(), 1):team()) then
                tile:set_team(self:team(), false)
            elseif is_omega and texture_part == "arm_lower" and not self:is_team(tile:team()) then
                tile:set_state(negative_tile_array[rng])
            end
            if not self:is_sliding() then
                if tile:is_edge() and self.slide_started then self:delete() end
                local dest = self:get_tile(direction, 1)
                local ref = self
                if dest and #dest:find_obstacles(obstacle_query) > 0 then
                    self.obstacle_hit = true
                    self:delete()
                end
                self:slide(dest, 6, function()
                    ref.slide_started = true
                    if texture_part == "arm_upper" then
                        drop_trace_fx(self, 240, { 0, 50, 150 })
                    else
                        drop_trace_fx(self, 120, { 100, 100, 100 })
                    end
                    tile:attack_entities(self)
                end)
            end
        else
            self.cooldown = self.cooldown - 1
        end
    end
    spell.on_collision_func = function(self, other)
        local check = Obstacle.from(other)
        if check ~= nil then self:delete() end
    end
    spell.on_delete_func = function(self)
        if not arm:deleted() then
            if texture_part == "arm_lower" or self.obstacle_hit then
                alpha.upper_arm:reveal()
                alpha.upper_arm:enable_hitbox(true)
                -- alpha.upper_arm:enable_sharing_tile(false)
                alpha.lower_arm:reveal()
                alpha.lower_arm:enable_hitbox(true)
                -- alpha.lower_arm:enable_sharing_tile(false)
                alpha.is_acting = false
            end
            self:erase()
        end
    end
    spell.can_move_to_func = function(tile)
        return true
    end

    return spell
end

local function take_devil_hand_action(alpha, texture_part, is_omega)
    alpha.is_acting = true                                  --Set alpha to acting so we don't spam claws.

    local field = alpha:field()                             --Get the field so we can spawn the spell.
    local mob_move = create_mob_move(mob_move_texture, "2") --Create an artifact to visually warp the claw.
    local damage = 50
    if alpha:rank() == Rank.SP then damage = 100 end
    local props = HitProps.new(
        damage,
        Hit.Impact | Hit.Flinch | Hit.Flash,
        Element.None,
        alpha:context(),
        Drag.None
    )

    local spell = create_devil_hand(alpha, props, texture_part, is_omega)
    local target = find_best_target(alpha)        --Get the player to attack them.
    if target and not target:deleted() then
        local target_tile = target:current_tile() --Get their tile.
        local desired_tile = nil
        if texture_part == "arm_upper" then
            alpha.upper_arm:hide() --Hide the upper arm. We're going to be spawning a spell that looks like it.
            alpha.upper_arm:enable_hitbox(false)
            alpha.upper_arm:enable_sharing_tile(true)
            if is_omega then
                desired_tile = field:tile_at(3, 0)                --Hover over the player's third column
            else
                desired_tile = field:tile_at(target_tile:x(), 0)  --Hover on the edge tile above them.
            end
            field:spawn(mob_move, alpha.upper_arm:current_tile()) --Spawn the artifact as we hide the arm so it looks good.
        elseif texture_part == "arm_lower" then
            alpha.lower_arm:hide()                                --Hide the upper arm. We're going to be spawning a spell that looks like it.
            alpha.lower_arm:enable_hitbox(false)
            alpha.lower_arm:enable_sharing_tile(true)
            local goal_x = 4
            if alpha:team() == Team.Red then goal_x = 3 end
            desired_tile = field:tile_at(goal_x, target_tile:y())
            field:spawn(mob_move, alpha.lower_arm:current_tile()) --Spawn the artifact as we hide the arm so it looks good.
        end
        local other_query = function(o)
            return Obstacle.from(o) ~= nil and o:team() ~= alpha:team()
        end

        if desired_tile ~= nil then
            local list = desired_tile:find_entities(other_query)
            if #list == 0 then
                field:spawn(spell, desired_tile)
            else
                alpha.is_acting = false
            end
        end
    else
        alpha.is_acting = false
    end
end

function character_init(alpha)
    alpha.is_acting = false
    alpha.vulcan_shots = 0
    alpha.anim_once = true
    alpha:set_name("Alpha")
    local health = 2000
    if alpha:rank() == Rank.SP then health = 3000 end
    alpha:set_health(health)
    alpha:set_texture(core_texture)

    alpha:ignore_negative_tile_effects(true)

    alpha.core_anim = alpha:animation()
    alpha.core_anim:load("alpha_core.animation")
    alpha.core_anim:set_state("CORE")
    alpha.core_anim:set_playback(Playback.Loop)


    local armor = alpha:create_node()                        --Nodes automatically attach to what you create them off of. No need to spawn!
    armor:set_texture(alpha:texture())                       --Just set their texture...
    alpha.armor_anim = Animation.new("alpha_core.animation") --And they have no get_animation, so we create one...
    armor:set_layer(-3)                                      --Set their layer, they're already a sprite...
    alpha.armor_anim:copy_from(alpha:animation())            --Load or copy the animation and do the normal stuff...
    alpha.armor_anim:set_state("ARMOR_IDLE")
    alpha.armor_anim:apply(armor)
    alpha.armor_anim:set_playback(Playback.Loop)

    local pool = alpha:create_node() --Need one for the pool too.
    pool:set_texture(pool_texture)
    alpha.pool_anim = Animation.new("pool.animation")
    alpha.pool_anim:set_state("0")
    alpha.pool_anim:apply(pool)
    alpha.pool_anim:set_playback(Playback.Loop)
    pool:set_layer(1)

    local ref = alpha

    alpha:add_aux_prop(StandardEnemyAux.new())
    alpha.goop_defense = DefenseRule.new(DefensePriority.Last, DefenseOrder.CollisionOnly)
    alpha.goop_health = 40
    alpha.previous_goop_health = 40
    alpha.regen_component = alpha:create_component(Lifetime.ActiveBattle)
    alpha.regen_component.cooldown = 0
    alpha.regen_component.cooldown_max = 240
    alpha.regen_component.on_update_func = function(self)
        if self.cooldown < 0 then
            ref.goop_health = math.min(40, ref.goop_health + 20)
            self.cooldown = self.cooldown_max
        else
            self.cooldown = self.cooldown - 1
        end
    end

    local state_table = {
        "COIL_SPAWN",
        "COIL_ATTACK",
        "COIL_RETREAT",
        "ROCKET_SPAWN",
        "VULCAN_IDLE",
        "VULCAN_ATTACK"
    }

    local check_state = "COIL_SPAWN" -- try replacing with one of the above

    local function is_any(item, set)
        for k, v in pairs(set) do
            if item == v then return true end
        end

        return false
    end
    alpha.goop_animation = alpha:create_component(Lifetime.ActiveBattle)
    alpha.goop_animation.on_update_func = function(self)
        check_state = ref.core_anim:state()
        if not ref.sigma_attack and not ref.omega_attack and not is_any(check_state, state_table) then
            if ref.goop_health ~= ref.previous_goop_health then
                if ref.goop_health <= 0 and check_state ~= "CORE_VULNERABLE_2" then
                    ref.core_anim:set_state("CORE_DAMAGE_2")
                    ref.core_anim:on_frame(3, function()
                        ref.is_vulnerable = true
                    end)
                    ref.core_anim:on_complete(function()
                        ref:ignore_negative_tile_effects(false)
                        ref.core_anim:set_state("CORE_VULNERABLE_2")
                        ref.core_anim:set_playback(Playback.Loop)
                    end)
                elseif ref.goop_health == 20 and check_state ~= "CORE_VULNERABLE" then
                    ref.core_anim:set_state("CORE_DAMAGE")
                    ref:ignore_negative_tile_effects(true)
                    ref.core_anim:on_frame(2, function()
                        ref.is_vulnerable = false
                    end)
                    ref.core_anim:on_complete(function()
                        ref.core_anim:set_state("CORE_VULNERABLE")
                        ref.core_anim:set_playback(Playback.Loop)
                    end)
                elseif ref.goop_health == 40 and check_state ~= "CORE" then
                    ref.core_anim:set_state("CORE_DAMAGE")
                    ref:ignore_negative_tile_effects(true)
                    ref.core_anim:set_playback(Playback.Reverse)
                    ref.core_anim:on_frame(2, function()
                        ref.is_vulnerable = false
                    end)
                    ref.core_anim:on_complete(function()
                        ref.core_anim:set_state("CORE")
                        ref.core_anim:set_playback(Playback.Loop)
                    end)
                end
            end
        end
        ref.previous_goop_health = ref.goop_health
    end

    alpha.is_vulnerable = false

    alpha.goop_defense.defense_func = function(defense, attacker, defender)
        if not ref.is_vulnerable then
            defense:block_damage()
            local props = attacker:copy_hit_props()
            props.damage = math.min(20, props.damage)
            attacker:set_hit_props(props)
            if ref.goop_health > 20 then
                ref.goop_health = math.max(20, ref.goop_health - props.damage)
            else
                ref.goop_health = math.max(0, ref.goop_health - props.damage)
            end
        end
    end

    alpha:add_defense_rule(alpha.goop_defense)
    alpha.upper_arm = Obstacle.new(alpha:team())
    alpha.upper_arm:set_texture(upper_arm_texture)
    alpha.upper_arm:set_health(99999)
    alpha.upper_arm_anim = alpha.upper_arm:animation()
    alpha.upper_arm_anim:load("arm_upper.animation")
    alpha.upper_arm_anim:set_state("IDLE")

    alpha.upper_arm_anim:set_playback(Playback.Loop)
    alpha.upper_arm:sprite():set_layer(-4)

    alpha.lower_arm = Obstacle.new(alpha:team())
    alpha.lower_arm:set_health(99999)
    alpha.lower_arm:set_texture(lower_arm_texture)
    alpha.lower_arm_anim = alpha.lower_arm:animation()
    alpha.lower_arm_anim:load("arm_lower.animation")
    alpha.lower_arm_anim:set_state("IDLE")

    alpha.lower_arm_anim:set_playback(Playback.Loop)
    alpha.lower_arm:sprite():set_layer(-4)


    alpha.flare = nil
    alpha.vulcan_texture = vulcan_texture
    alpha.flare_cooldown = 8

    local field = nil
    alpha.on_battle_start_func = function()
        field = alpha:field()
        local friends_list = field:find_characters(function(ent)
            return ent and alpha:is_team(ent:team())
        end)
        for x = 1, 6, 1 do
            for y = 1, 3, 1 do
                local tile = field:tile_at(x, y)
                if tile:team() == alpha:team() then
                    for c = 1, #friends_list, 1 do
                        field:tile_at(x, y):reserve_for_id(tonumber(friends_list[c]:id()))
                    end
                end
            end
        end
    end

    alpha.on_spawn_func = function()
        field = alpha:field()
        alpha.upper_arm:add_defense_rule(create_claw_defense(alpha.upper_arm))
        alpha.upper_arm:set_team(alpha:team())
        alpha.upper_arm:set_facing(alpha:facing())
        field:spawn(alpha.upper_arm, alpha:get_tile(Direction.join(alpha:facing(), Direction.Up), 1))
        alpha.lower_arm:add_defense_rule(create_claw_defense(alpha.lower_arm))
        alpha.lower_arm:set_team(alpha:team())
        alpha.lower_arm:set_facing(alpha:facing())
        field:spawn(alpha.lower_arm, alpha:get_tile(alpha:facing_away(), 1))
    end
    alpha.can_move_to_func = function(tile)
        return false
    end
    alpha.cooldown = 150
    alpha.vulcan_attack = false
    alpha.omega_attack = false
    alpha.sigma_attack = false
    alpha.sigma_count = 0
    alpha.alpha_arm = nil
    alpha.alpha_arm_type = { "SIGMA", "OMEGA" }
    alpha.alpha_arm_index = 1
    alpha.sigma_state = { "SINGLE ROW", "DOUBLE ROW" }
    alpha.sigma_index = 1
    alpha.pattern = {
        "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "REVERSE VULCAN",
        "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "RED EYE DELETE"
    }
    alpha.low_health_pattern = {
        "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "ALPHA ARM",
        "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "RED EYE DELETE"
    }
    alpha.omega_pattern = {
        "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "REVERSE VULCAN",
        "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "RED EYE DELETE",
        "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "GOD HAND", "GOD HAND"
    }
    alpha.low_health_pattern_omega = {
        "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "ALPHA ARM",
        "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "RED EYE DELETE",
        "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "DEVIL HAND", "GOD HAND", "GOD HAND"
    }
    alpha.pattern_index = 1
    alpha.devil_hand_list = { "arm_upper", "arm_lower" }
    alpha.devil_hand_index = 1
    local has_changed_armor = false
    local activity = alpha.pattern[alpha.pattern_index]
    local rank = alpha:rank()
    alpha.on_update_func = function(self)
        if self:deleted() then
            self.upper_arm:delete()
            self.lower_arm:delete()
            return
        end

        self.armor_anim:apply(armor)
        self.armor_anim:update()
        self.pool_anim:apply(pool)
        self.pool_anim:update()

        -- print(self.cooldown)
        if self.cooldown <= 0 then
            if not self.is_acting then
                if not has_changed_armor and self:health() <= math.floor(health / 2) and self.armor_anim:state() == "ARMOR_IDLE" then
                    self.armor_anim:set_state("ARMOR_IDLE_FAST")
                    self.armor_anim:set_playback(Playback.Loop)
                end
                if rank == Rank.SP then
                    activity = self.omega_pattern[self.pattern_index]
                else
                    activity = self.pattern[self.pattern_index]
                end
                if self:health() <= math.floor(health / 2) then
                    if rank == Rank.SP then
                        activity = self.low_health_pattern_omega[self.pattern_index]
                    else
                        activity = self.low_health_pattern[self.pattern_index]
                    end
                end

                if self.vulcan_attack then
                    activity = "REVERSE VULCAN"
                end

                if activity == "DEVIL HAND" then
                    take_devil_hand_action(self, self.devil_hand_list[self.devil_hand_index], false)
                    self.pattern_index = self.pattern_index + 1
                    self.devil_hand_index = self.devil_hand_index + 1
                    if self.devil_hand_index > #self.devil_hand_list then self.devil_hand_index = 1 end
                    self.cooldown = 40
                elseif activity == "GOD HAND" then
                    take_devil_hand_action(self, self.devil_hand_list[self.devil_hand_index], true)
                    self.pattern_index = self.pattern_index + 1
                    self.devil_hand_index = self.devil_hand_index + 1
                    if self.devil_hand_index > #self.devil_hand_list then self.devil_hand_index = 1 end
                    self.cooldown = 40
                elseif activity == "REVERSE VULCAN" then
                    if self.vulcan_attack and self.vulcan_shots < 16 then
                        print("rev vulc, vulc atk true, shots < 16")
                        take_reverse_vulcan_action(self)
                        self.cooldown = 13
                    end
                    if self.anim_once and self.vulcan_shots < 16 then
                        print("anim once: vulcan reveal, shots < 16")
                        self.anim_once = false

                        self.armor_anim:set_state("VULCAN_REVEAL")
                        self.armor_anim:set_playback(Playback.Once)
                        self.armor_anim:apply(armor)

                        Resources.play_audio(reverse_vulcan_spawn_sound)

                        self.armor_anim:on_complete(function()
                            print("pause start")
                            self.armor_anim:set_state("VULCAN_PAUSE")
                            self.armor_anim:apply(armor)
                            self.armor_anim:on_complete(function()
                                print("vulc pause done")
                                self.armor_anim:set_state("VULCAN_SHOOT")
                                self.armor_anim:apply(armor)
                                self.armor_anim:set_playback(Playback.Loop)
                                self.vulcan_attack = true
                                self.flare = create_reverse_vulcan_flare(self, self.vulcan_texture)
                                if field ~= nil then field:spawn(self.flare, self:current_tile()) end
                            end)
                        end)
                    elseif self.anim_once and self.vulcan_shots >= 16 then
                        self.anim_once = false
                        self.armor_anim:set_state("VULCAN_REVEAL")
                        self.armor_anim:set_playback(Playback.Reverse)
                        self.armor_anim:on_complete(function()
                            if self:health() <= math.floor(health / 2) then
                                self.armor_anim:set_state("ARMOR_IDLE_FAST")
                            else
                                self.armor_anim:set_state("ARMOR_IDLE")
                            end
                            self.armor_anim:set_playback(Playback.Loop)
                            self.pattern_index = self.pattern_index + 1
                            self.vulcan_attack = false
                            self.vulcan_shots = 0
                            self.anim_once = true
                            self.cooldown = 23
                        end)
                    end
                elseif activity == "RED EYE DELETE" then
                    take_red_eye_action(self, "ATTACK_CHARGE")
                    self.pattern_index = self.pattern_index + 1
                elseif activity == "ALPHA ARM" then
                    if self.sigma_attack and self.sigma_count < 16 then
                        self.alpha_arm = take_alpha_arm_action(self, self.alpha_arm_type[self.alpha_arm_index])
                    end
                    if self.sigma_count >= 16 then
                        self.sigma_count = 0
                        self.sigma_attack = false
                        if self.alpha_arm ~= nil then
                            self.alpha_arm:delete()
                            self.alpha_arm = nil
                        end
                        self.core_anim:set_state("COIL_RETREAT")
                        self.core_anim:on_complete(function()
                            self.core_anim:set_state("CORE")
                            self.core_anim:set_playback(Playback.Loop)
                            end_alpha_arm(self)
                        end)
                    end
                    if self.anim_once then
                        self.upper_arm:hide()
                        self.lower_arm:hide()
                        self.upper_arm:enable_hitbox(false)
                        self.lower_arm:enable_hitbox(false)
                        self.anim_once = false
                        if self.alpha_arm_type[self.alpha_arm_index] == "SIGMA" then
                            self.core_anim:set_state("COIL_SPAWN")
                            self.core_anim:on_complete(function()
                                self.core_anim:set_state("COIL_ATTACK")
                                self.core_anim:set_playback(Playback.Loop)
                                self.sigma_attack = true
                            end)
                        elseif self.alpha_arm_type[self.alpha_arm_index] == "OMEGA" then
                            self.omega_attack = true
                            Resources.play_audio(omega_rocket_spawn_sound)
                            self.core_anim:set_state("ROCKET_SPAWN")
                            self.core_anim:on_frame(5, function()
                                take_alpha_arm_action(self, self.alpha_arm_type[self.alpha_arm_index])
                            end)
                            self.core_anim:on_complete(function()
                                self.core_anim:set_state("CORE")
                                self.core_anim:set_playback(Playback.Loop)
                                end_alpha_arm(self)
                            end)
                        end
                    end
                end
                if self.pattern_index > #self.pattern then self.pattern_index = 1 end
            end
        else
            self.cooldown = self.cooldown - 1
        end
    end
end
