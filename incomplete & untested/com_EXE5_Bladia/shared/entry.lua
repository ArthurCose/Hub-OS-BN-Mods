local function create_smoke(self, anim_state)
    local smoke = Spell.new(self:team())
    smoke:set_texture(Resources.load_texture("teleport.png"), true)
    smoke:sprite():set_layer(-2)
    local animation = smoke:animation()
    animation:load("teleport.animation")
    animation:set_state(anim_state)
    animation:apply(smoke:sprite())
    animation:on_complete(function()
        smoke:erase()
    end)
    return smoke
end

local function spawn_attack_visual(team, tile, field)
    local visual = Spell.new(team)
    visual:set_texture(Resources.load_texture("hit_effect.png"))
    local anim = visual:animation()
    anim:load("hit_effect.animation")
    anim:apply(visual:sprite())
    anim:set_state("DEFAULT")
    visual:sprite():set_layer(-3)
    anim:on_complete(function()
        visual:erase()
    end)
    field:spawn(visual, tile)
end

local function increment_pattern(self)
    self.guard_index = 1
    self.can_block = true
    self.should_block = false
    self.pattern_index = self.pattern_index + 1
    if self.pattern_index > #self.pattern then self.pattern_index = 1 end
    self.pattern_cooldown_index = self.pattern_cooldown_index + 1
    if self.pattern_cooldown_index > #self.pattern_cooldown_list then self.pattern_cooldown_index = 1 end
    self.anim_once = true
    if self.is_guarding or self.defense ~= nil then
        self.is_guarding = false
        self:remove_defense_rule(self.defense)
    end
    self.pattern_cooldown = self.pattern_cooldown_list[self.pattern_cooldown_index]
end

local function warp(self, anim_state)
    local smoke = create_smoke(self, anim_state)
    local field = self:field()
    local facing = self:facing()
    local i = 1
    local goal = 6
    local increment = 1
    if facing == Direction.Right then
        i = 6
        goal = 1
        increment = -1
    end
    for x = i, goal, increment do
        for y = 1, 3, 1 do
            local prospective_tile = field:tile_at(x, y)
            if self:can_move_to(prospective_tile) then
                self.warp_tile = prospective_tile
                break
            end
        end
    end
    field:spawn(smoke, self:current_tile())
    local c = self:create_component(Lifetime.Battle)
    c.duration = 60
    c.start_tile = self:current_tile()
    c.target_tile = self.warp_tile
    c.owner = self
    c.smoke = create_smoke(self, "BIG_TELEPORT_TO")
    c.on_update_func = function(self)
        if self.owner:health() == 0 then
            self:eject()
            return
        end
        self.duration = self.duration - 1
        if self.duration == 10 then
            local owner_anim = self.owner:animation()
            owner_anim:set_state("IDLE")
            owner_anim:apply(self.owner:sprite())
            owner_anim:set_playback(Playback.Loop)
        end
        if self.duration <= 0 then
            increment_pattern(self.owner)
            self.target_tile:add_entity(self.owner)
            field:spawn(self.smoke, self.target_tile)
            self.owner.can_block = true --Enable blocking.
            self:eject()
        end
    end
    c.on_init_func = function(self)
        local id = self:owner():id()
        self.owner:current_tile():remove_entity_by_id(id)
        self.target_tile:reserve_for_id(id)
    end
end

local function spawn_attack(self)
    if self.tile ~= nil and self.panels ~= nil then
        local spell = Spell.new(self:team())
        spell:set_hit_props(
            HitProps.new(
                self.attack,
                Hit.Impact | Hit.Flinch | Hit.Flash | Hit.PierceInvis,
                Element.None,
                self:context(),
                Drag.None
            )
        )
        spell.duration = 4
        for i = 1, #self.panels, 1 do
            self.panels[i]:set_state(TileState.Cracked)
        end
        spell.on_update_func = function()
            spell.duration = spell.duration - 1
            if spell.duration == 0 then
                spell:delete()
                return
            end
            for i = 1, #self.panels, 1 do
                self.panels[i]:set_highlight(Highlight.Flash)
                self.panels[i]:attack_entities(spell)
            end
        end
        spell.on_collision_func = function(self)
            self:delete()
        end
        spell.on_delete_func = function(self)
            for i = 1, #self.panels, 1 do
                self.panels[i]:set_highlight(Highlight.None)
            end
            spell:erase()
            self.tile = nil
            self.panels = nil
        end
        local field = self:field()
        field:spawn(spell, self.tile)
        Resources.play_audio(Resources.load_audio("sounds/attack.ogg", true))
        spawn_attack_visual(self:team(), self.tile, field)
    end
end

local function spawn_attack_highlight(self)
    --Don't do anything if the target is dead.
    if not self.target or self.target and self.target:deleted() then return end
    --Get the tile to highlight.
    local tile = self.target:current_tile()
    --Adjust if it's not the middle tile.
    if tile:y() > 2 then
        tile = tile:get_tile(Direction.Up, 1)
    elseif tile:y() < 2 then
        tile = tile:get_tile(Direction.Down, 1)
    end
    --Now grab all three once we guarantee we're in the middle.
    local panels = { tile, tile:get_tile(Direction.Up, 1), tile:get_tile(Direction.Down, 1) }
    local spell = Spell.new(self:team())
    spell.timer = 48
    spell.on_update_func = function(self)
        self.timer = self.timer - 1
        if self.timer == 0 then
            self:erase()
            return
        end
        for i = 1, #panels, 1 do
            panels[i]:set_highlight(Highlight.Flash)
        end
    end
    self.target:field():spawn(spell, tile)
    self.tile = tile
    self.panels = panels
end

local function find_best_target(self)
    local target = nil
    local field = self:field()
    local query = function(c)
        return c:team() ~= self:team()
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

function character_init(self, character_info)
    self:set_texture(Resources.load_texture("bladia.greyscaled.png"))
    self:set_palette(Resources.load_texture(character_info.palette))
    local anim = self:animation()
    anim:load("bladia.animation")
    anim:set_state("SPAWN")
    anim:apply(self:sprite())
    self:set_health(tonumber(character_info.hp))
    self.attack = character_info.attack
    self:set_name(character_info.name)
    local field = nil
    self.on_battle_start_func = function(self)
        field = self:field()
        anim:set_state("IDLE")
        anim:apply(self:sprite())
        anim:set_playback(Playback.Loop)
    end
    self.tile = nil
    self.target = nil
    self.panels = nil
    self.pattern = { "IDLE", "ATTACK", "WARP" }
    self.pattern_index = 1
    self.pattern_cooldown_list = { 180, 168, 60 } --How long each state lasts. Idle for 180 frames. Attack for 168 frames. Vanish for 60 before reappearing. Reset.
    self.pattern_cooldown_index = 1
    self.anim_once = true
    self.guard_chances = { 33, 67, 100 } --Chance to guard. Every time we detect an attack and fail to guard, increment the chance for next time.
    self.guard_index = 1
    self.attack_find_query = function(s)
        if s then
            if Character.from(s) ~= nil or Obstacle.from(s) ~= nil or Player.from(s) ~= nil then return false end
            return s:current_tile():y() == self:current_tile():y() and s:team() ~= self:team()
        end
        return false
    end
    self:add_aux_prop(StandardEnemyAux.new())
    local tink = Resources.load_audio("sounds/tink.ogg")
    local guard_texture = Resources.load_texture("guard_hit.png")
    self.pattern_cooldown = self.pattern_cooldown_list[self.pattern_cooldown_index]
    self.is_guarding = false
    self.defense = nil
    self.warp_tile = nil
    local occupied_query = function(ent)
        return Obstacle.from(ent) ~= nil or Character.from(ent) ~= nil
    end
    self.can_move_to_func = function(tile)
        if not tile then return false end
        if tile:is_edge() then return false end
        if #tile:find_entities(occupied_query) > 0 then return false end
        return true
    end
    self.can_block = true     --Bool used to determine if we can block right now. Turns off when blocking & when in certain animations.
    self.should_block = false --Bool used to determine if an attack worth blocking is found.
    self.on_update_func = function(self)
        if not self.is_guarding and self.can_block then
            local attacks = field:find_entities(self.attack_find_query)
            if #attacks > 0 then
                --Collapsed for loop. Goes over the attack list and checks if any have a damage value over 0.
                --If so, tells Bladia he should try to block.
                for i = 1, #attacks, 1 do
                    if attacks[i]:copy_hit_props().damage > 0 then
                        self.should_block = true
                        break
                    end
                end
                if math.random(1, 100) <= self.guard_chances[self.guard_index] and self.should_block then
                    self.is_guarding = true
                    self.should_block = false
                    self.can_block = false --Disable blocking while already blocking.
                    anim:set_state("BLOCK")
                    anim:on_frame(2, function()
                        self.defense = DefenseRule.new(DefensePriority.Last, DefenseOrder.CollisionOnly)
                        self.defense.owner = self
                        self.defense.can_block_func = function(judge, attacker, defender)
                            --Don't block if has the breaking flag
                            if attacker:copy_hit_props().flags & Hit.PierceGuard == Hit.PierceGuard then return end
                            --If no breaking flag then block, play the sound and animation
                            judge:block_damage()
                            judge:block_impact()
                            Resources.play_audio(tink)
                            local xset = math.random(10, 50)
                            local yset = math.random(35, 50)
                            xset = xset * -1
                            yset = yset * -1
                            if defender:facing() == Direction.Right then xset = xset * -1 end
                            local shine = Spell.new(defender:team())
                            shine:set_offset(xset * 0.5, yset * 0.5)
                            shine:set_texture(guard_texture)
                            local shine_anim = shine:animation()
                            shine_anim:load("guard_hit.animation")
                            shine_anim:set_state("DEFAULT")
                            shine_anim:apply(shine:sprite())
                            shine:sprite():set_layer(-2)
                            shine_anim:on_complete(function()
                                shine:delete()
                            end)
                            defender:field():spawn(shine, defender:current_tile())
                        end
                        self:add_defense_rule(self.defense)
                    end)
                    anim:on_complete(function()
                        self:remove_defense_rule(self.defense)
                        self.is_guarding = false
                        self.can_block = true
                    end)
                else
                    self.can_block = true
                    self.is_guarding = false
                    self.guard_index = self.guard_index + 1
                    if self.guard_index > #self.guard_chances then self.guard_index = #self.guard_chances end
                end
            end
        end
        if self.pattern_cooldown > 0 then
            self.pattern_cooldown = self.pattern_cooldown - 1
            return
        end
        if self.pattern[self.pattern_index] == "IDLE" and self.anim_once then
            self.anim_once = false
            anim:set_state("IDLE")
            anim:apply(self:sprite())
            anim:set_playback(Playback.Loop)
            increment_pattern(self)
        elseif self.pattern[self.pattern_index] == "ATTACK" and self.anim_once then
            self.anim_once = false
            self.target = find_best_target(self)
            anim:set_state("ATTACK")
            anim:apply(self:sprite())
            anim:on_frame(1, function()
                if self.defense ~= nil then self:remove_defense_rule(self.defense) end
                self.can_block = false --Disable blocking.
            end)
            anim:on_frame(3, function()
                spawn_attack_highlight(self)
            end)
            anim:on_frame(4, function()
                self:set_counterable(true)
            end)
            anim:on_frame(6, function()
                self:set_counterable(false)
                self:field():shake(8.0, 36)
                spawn_attack(self)
            end)
            anim:on_complete(function()
                increment_pattern(self)
                self.can_block = false
            end)
        elseif self.pattern[self.pattern_index] == "WARP" and self.anim_once then
            self.anim_once = false
            self.can_block = false
            warp(self, "BIG_TELEPORT_FROM")
        end
    end
end

return package_init
