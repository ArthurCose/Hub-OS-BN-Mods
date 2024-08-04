local spawn_sound = Resources.load_audio("Sounds/scanning_click.ogg")
local lock_sound = Resources.load_audio("Sounds/scanning_lock.ogg")

local cursor_texture = Resources.load_texture("Cursor.png")
local hit_texture = Resources.load_texture("Hit Effect.png")
local main_texture = Resources.load_texture("Basher.png")

local function find_best_target(self)
    local target = nil
    local field = self.field
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

local function spawn_hit_effect(field, tile)
    local effect = Spell.new(Team.Other)
    effect:set_texture(hit_texture)
    local anim = effect:animation()
    anim:load("Hit Effect.animation")
    anim:set_state("DEFAULT")
    anim:apply(effect:sprite())
    anim:on_complete(function()
        effect:erase()
    end)
    field:spawn(effect, tile)
end

local function tile_logic(self)
    local tiles = {}
    local tile = self.field:tile_at(self:current_tile():x(), 2)
    local dir = self:facing(self)
    local count = 1
    local max = 6
    local tile_front = nil
    local tile_up = nil
    local tile_down = nil

    local check_front = false
    local check_up = false
    local check_down = false
    for i = count, max, 1 do
        tile_front = tile:get_tile(dir, i)
        tile_up = tile_front:get_tile(Direction.Up, 1)
        tile_down = tile_front:get_tile(Direction.Down, 1)

        check_front = tile_front and self:team() ~= tile_front:team() and not tile_front:is_edge() and
            tile_front:team() ~= Team.Other and self:is_team(tile_front:get_tile(Direction.reverse(dir), 1):team())
        check_up = tile_up and self:team() ~= tile_up:team() and not tile_up:is_edge() and tile_up:team() ~= Team.Other and
            self:is_team(tile_up:get_tile(Direction.reverse(dir), 1):team())
        check_down = tile_down and self:team() ~= tile_down:team() and not tile_down:is_edge() and
            tile_down:team() ~= Team.Other and self:is_team(tile_down:get_tile(Direction.reverse(dir), 1):team())

        if check_front or check_up or check_down then
            table.insert(tiles, tile_front)
            table.insert(tiles, tile_up)
            table.insert(tiles, tile_down)
            break
        end
    end
    return tiles
end

local function spawn_cursors(self)
    --Don't do anything if the target is dead.
    if not self.target or self.target and self.target:deleted() then return end
    local tile_array = tile_logic(self)
    self.action = "CURSOR"
    for i = 1, #tile_array, 1 do
        local spell = Spell.new(self:team())

        spell.can_move_to_func = function(tile) return true end
        spell:set_facing(self:facing())
        spell:sprite():set_layer(-2)
        spell:set_texture(cursor_texture)
        local anim = spell:animation()
        anim:load("Cursor.animation")
        anim:apply(spell:sprite())
        anim:set_state("SPAWN")
        Resources.play_audio(spawn_sound, AudioBehavior.NoOverlap)
        spell.find_foes = function(foe)
            return foe and foe:health() > 0 and foe:team() ~= spell:team()
        end
        spell.is_attack = false
        spell.owner = self
        spell.anim = spell:animation()
        spell.anim:on_complete(function()
            if #spell:current_tile():find_characters(spell.find_foes) > 0 then
                Resources.play_audio(lock_sound, AudioBehavior.NoOverlap)
                for x = 1, #self.cursor_table, 1 do
                    local cursor = self.cursor_table[x]
                    local c_anim = cursor:animation()
                    c_anim:set_state("LOCKON")
                    c_anim:apply(cursor:sprite())
                    cursor.cooldown = 99999
                    cursor.hide_cooldown = 99999
                    c_anim:on_complete(function()
                        self.is_attack = true
                        cursor.is_attack = true
                        cursor:sprite():hide()
                    end)
                end
            end
        end)
        anim:set_playback(Playback.Once)
        spell.cooldown = 30
        spell.hide_cooldown = 30
        spell.on_delete_func = function(self)
            self.owner.is_attack = false
            self.owner.action = nil
            self.owner.cooldown = 54
            self.owner.cursor_table = {}
            self:erase()
        end
        spell.audio_once = true
        spell.is_hidden = false
        spell.on_update_func = function(self)
            if self.is_hidden then
                self.hide_cooldown = self.hide_cooldown - 1
                if self.hide_cooldown == 0 then
                    local dest = self:get_tile(self:facing(), 1)
                    if dest and not dest:is_edge() then
                        self.is_hidden = false
                        self.cooldown = 30
                        self:sprite():reveal()
                        self:teleport(dest, function()
                            anim:set_state("SPAWN")
                            Resources.play_audio(spawn_sound, AudioBehavior.NoOverlap)
                        end)
                    else
                        self:delete()
                    end
                end
                return
            else
                self.cooldown = self.cooldown - 1
                if self.cooldown == 0 then
                    self.is_hidden = true
                    self.hide_cooldown = 30
                    self:sprite():hide()
                end
            end
            self.is_attack = #self:current_tile():find_characters(self.find_foes) > 0
            if self.is_attack then
                if self.audio_once then
                    self.audio_once = false
                    self.cooldown = 99999
                    self.hide_cooldown = 99999
                    Resources.play_audio(lock_sound, AudioBehavior.NoOverlap)
                    for i = 1, #self.owner.cursor_table, 1 do
                        local cursor = self.owner.cursor_table[i]
                        local c_anim = cursor:animation()
                        c_anim:set_state("LOCKON")
                        c_anim:apply(cursor:sprite())
                        cursor.cooldown = 99999
                        cursor.hide_cooldown = 99999
                        c_anim:on_complete(function()
                            self.owner.is_attack = true
                            cursor.is_attack = true
                            cursor:sprite():hide()
                        end)
                    end
                end
            end
        end
        table.insert(self.cursor_table, spell)
        self.field:spawn(spell, tile_array[i])
    end
end

function character_init(basher)
    basher:set_texture(main_texture)
    local rank = basher:rank()
    local anim = basher:animation()
    anim:load("Basher.animation")
    anim:set_state("SPAWN")
    anim:apply(basher:sprite())
    if rank == Rank.V1 then
        basher:set_name("Basher")
        basher:set_health(150)
        basher.attack = 50
    end
    basher.field = nil
    basher.on_battle_start_func = function(self)
        self.field = basher:field()
        anim:set_state("IDLE")

        anim:set_playback(Playback.Loop)
    end
    basher.target = nil
    basher.panels = nil
    basher.find_enemy_query = function(c)
        return c and c:health() > 0 and (Character.from(c) ~= nil or Player.from(c) ~= nil)
    end
    basher.cursor_table = {}
    basher:add_aux_prop(StandardEnemyAux.new())
    basher.can_move_to_func = function(tile) return false end
    basher.cooldown = 54
    basher.is_attack = false
    basher.action = nil
    basher.anim_once = true
    basher.on_update_func = function(self)
        if self:deleted() then return end
        if self and not self:hittable() then return end
        self.cooldown = self.cooldown - 1
        if self.cooldown <= 0 then
            if self.is_attack then
                if self.anim_once then
                    self.anim_once = false
                    anim:set_state("RISE")

                    anim:on_frame(9, function()
                        self:set_counterable(true)
                    end)
                    anim:on_complete(function()
                        anim:set_state("SHOOT")

                        anim:on_frame(1, function()
                            for a = 1, #self.cursor_table, 1 do
                                local cursor = self.cursor_table[a]
                                -- Resources.play_audio(AudioType.Explode)
                                local props = HitProps.new(
                                    self.attack,
                                    Hit.Impact | Hit.Flinch | Hit.Flash | Hit.PierceGuard,
                                    Element.None,
                                    self:context(),
                                    Drag.None
                                )
                                local hitbox = Spell.new(self:team())
                                hitbox:set_hit_props(props)
                                local spawn_tile = cursor:current_tile()
                                local ref = self
                                hitbox.on_update_func = function(self)
                                    spawn_hit_effect(ref.field, spawn_tile)
                                    spawn_tile:attack_entities(self)
                                    spawn_tile:set_state(TileState.Cracked)
                                    spawn_tile:set_state(TileState.Broken)
                                    self:erase()
                                end
                                self.field:spawn(hitbox, spawn_tile)
                            end
                            self.field:shake(8.0, 36)
                            for b = 1, #self.cursor_table, 1 do
                                local cursor = self.cursor_table[b]
                                cursor:erase()
                            end
                            self.cursor_table = {}
                            self:set_counterable(false)
                        end)
                        anim:on_complete(function()
                            anim:set_state("LOWER")

                            anim:on_complete(function()
                                anim:set_state("IDLE")

                                anim:set_playback(Playback.Loop)
                                self.is_attack = false
                                self.action = nil
                                self.anim_once = true
                                self.cooldown = 54
                            end)
                        end)
                    end)
                end
                return
            end
            if self.action ~= nil then return end
            self.target = find_best_target(self)
            spawn_cursors(self)
        end
    end
end
