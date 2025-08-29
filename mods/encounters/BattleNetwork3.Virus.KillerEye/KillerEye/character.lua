local battle_helpers = require("battle_helpers.lua")
local character_animation = "battle.animation"
local anim_speed = 1
local scan_sfx = Resources.load_audio("scan.ogg")
local shock_sfx = Resources.load_audio("shock.ogg")
local hit_sfx = Resources.load_audio("hitsound.ogg")
local laser_texture = Resources.load_texture("laser.png")
local scan_texture = Resources.load_texture("dot.png")
local CHARACTER_TEXTURE = Resources.load_texture("battle.greyscaled.png")
local move_counter = 0
local effects_texture = Resources.load_texture("effect.png")
local effects_anim = "effect.animation"

function character_init(self, character_info)
    -- Required function, main package information
    -- Load character resources
    local base_animation_path = character_animation
    self:set_texture(CHARACTER_TEXTURE, true)
    self.animation = self:animation()
    self.animation:load(base_animation_path)
    -- self.animation:set_playback_speed(anim_speed)
    -- Load extra resources
    -- Set up character meta
    self:set_name(character_info.name)
    self:set_health(character_info.hp)
    self:set_height(character_info.height)
    self.damage = (character_info.damage)
    self:set_element(Element.Elec)
    self:enable_sharing_tile(false)
    -- self:set_explosion_behavior(4, 1, false)
    self:set_offset(0 * 0.5, 0 * 0.5)
    self:set_palette(Resources.load_texture(character_info.palette))
    self.frames_between_actions = 60
    self.steps = 8
    self.max_laser_duration = 118
    self.laser_duration = self.max_laser_duration - 1
    self.laserspells = {}
    self.started = false
    self.state = "attacking"
    self.look_direction = "downtoup"
    self:add_aux_prop(StandardEnemyAux.new())
    self.next_look_anim = nil
    self.animation:set_state("SPAWN")

    -- Initial state

    self.choose_next_direction = function(self)
        if (isForwardDirection(self.current_direction)) then
            local currentY = self:get_tile():y()
            if (currentY == 3) then
                --if bottom row, don't look down
                self.current_direction = Direction.join(self:facing(), Direction.Up)
                self.next_look_anim = "LOOK_UP"
                return
            elseif (currentY == 1) then
                --it top row, don't look up
                self.current_direction = Direction.join(self:facing(), Direction.Down)
                self.next_look_anim = "LOOK_DOWN"
                return
            end
            if (self.look_direction == "downtoup") then
                self.current_direction = Direction.join(self:facing(), Direction.Up)
                self.next_look_anim = "LOOK_UP"
            elseif self.look_direction == "uptodown" then
                self.current_direction = Direction.join(self:facing(), Direction.Down)
                self.next_look_anim = "LOOK_DOWN"
            end
        elseif (isUpDirection(self.current_direction)) then
            self.current_direction = self:facing()
            self.look_direction = "uptodown"
            self.next_look_anim = "LOOK_FORWARD_FROM_UP"
        elseif (isDownDirection(self.current_direction))
        then
            self.next_look_anim = "LOOK_FORWARD_FROM_DOWN"
            self.current_direction = self:facing()
            self.look_direction = "downtoup"
        end
    end
    self.on_update_func = function(self)
        if not self.started then
            self.animation:set_state("IDLE_FORWARD")
            self.current_direction = self:facing()
            self.started = true
        end
        self.laser_duration = self.laser_duration + 1
        if (self.state == "attacking" and self.laser_duration == self.max_laser_duration) then
            self:despawnLasers()
            self.state = "idle"
            self.animation:set_state(getIdleAnim(self))
            self:choose_next_direction()
            self.animation:on_complete(function()
                self.animation:set_state(self.next_look_anim)
                create_scanner(self)
                self.state = "scan"
            end)
        end
    end

    --despawn laser and scanners on deleted.
    self.on_delete_func = function(self)
        self:despawnLasers()
        --[[patch--]]
        self:erase() --[[end patch--]]
    end

    self.despawnLasers = function()
        for index, laser in ipairs(self.laserspells) do
            laser:erase()
            self.laserspells[index] = nil
        end
    end
end

function create_scanner(owner)
    local team = owner:team()
    local direction = owner.current_direction
    local max_scans = 9

    local spell = Spell.new(team)
    spell.nextile = owner:get_tile(direction, 1)
    spell.starttile = owner:get_tile(direction, 1)
    spell:set_facing(owner:facing())
    spell.wait_frames = 0
    spell.scans = 0
    spell:sprite():set_layer(-1)
    spell:set_hit_props(
        HitProps.new(
            0,
            Hit.None,
            Element.None,
            owner:context(),
            Drag.new()
        )
    )

    print(owner:name())

    local sprite = spell:sprite()
    sprite:set_texture(scan_texture)
    spell:set_offset(0 * 0.5, -20 * 0.5)

    local animation = spell:animation()
    animation:load("dot.animation")
    animation:set_state("0")
    animation:set_playback(Playback.Loop)
    animation:apply(sprite)

    spell.on_update_func = function()
        if (spell.nextile == nil or spell.nextile:is_edge()) then
            spell.nextile = spell.starttile
            return
        end
        if (spell.scans > max_scans or owner:deleted()) then
            spell:erase()
            skip_turn(owner)
        end
        spell.wait_frames = spell.wait_frames + 1
        if (spell.wait_frames == 8) then
            spell:teleport(spell.nextile)
            spell.scans = spell.scans + 1
            Resources.play_audio(scan_sfx, AudioBehavior.NoOverlap)
            spell.nextile = spell.nextile:get_tile(direction, 1)
            spell.wait_frames = 0
        end
        spell:current_tile():attack_entities(spell)
    end

    spell.can_move_to_func = function()
        return true
    end

    spell.on_collision_func = function(self)
        spell:erase()
        action_shock(owner)
        owner.wait_time = 0
    end
    Field.spawn(spell, spell.nextile)
end

function getAttackAnim(char)
    if (isForwardDirection(char.current_direction)) then
        return "ATTACK_FORWARD"
    elseif (isUpDirection(char.current_direction)) then
        return "ATTACK_UP"
    else
        return "ATTACK_DOWN"
    end
end

function getIdleAnim(char)
    if (isForwardDirection(char.current_direction)) then
        return "IDLE_FORWARD"
    elseif (isUpDirection(char.current_direction)) then
        return "IDLE_UP"
    elseif (isDownDirection(char.current_direction)) then
        return "IDLE_DOWN"
    else
    end
end

function skip_turn(character)
    -- sensor did not detect enemies, act as if character attacked so we can go into idle animation
    character.state = "attacking"
    character.laser_duration = character.max_laser_duration - 1
end

function action_shock(character)
    --begin the attack animation for laser
    character.state = "attacking"
    local attackAnim = getAttackAnim(character)
    local shock_anim = character.animation
    shock_anim:set_state(attackAnim)
    shock_anim:on_frame(1, function()
        character:set_counterable(true)
        Resources.play_audio(shock_sfx, AudioBehavior.Default)
    end)

    shock_anim:on_frame(5, function()
        spawn_laser(character)
        character.laser_duration = 0
    end)
    shock_anim:on_frame(6, function()
        character:set_counterable(false)
        character.steps = 0
        --character.animation:set_playback(Playback.Loop)
        character.state = "attacking"
    end)
end

function spawn_laser(owner)
    --spawn paralyzing laser for owner
    local team = owner:team()
    local direction = owner.current_direction
    local tile = owner:get_tile(direction, 1)
    local laser_hit_props = HitProps.new(
        owner.damage,
        Hit.Paralyze | Hit.Flinch | Hit.PierceInvis,
        Element.Elec,
        owner:context(),
        Drag.new()
    )
    local spawn_next
    local filter = function() return true end
    spawn_next = function()
        local spell = Spell.new(team)
        spell:set_facing(owner:facing())
        spell.current_entity = nil

        local sprite = spell:sprite()
        sprite:set_texture(laser_texture)
        spell:set_offset(0 * 0.5, -50 * 0.5)

        local animation = spell:animation()
        animation:load("laser.animation")
        if (isUpDirection(direction)) then
            animation:set_state("DIAGONAL_1")
        elseif (isDownDirection(direction)) then
            animation:set_state("DIAGONAL_2")
        else
            animation:set_state("Straight")
        end
        animation:set_playback(Playback.Loop)
        animation:apply(sprite)

        animation:on_frame(2, function()
            tile = getNextTile(direction, spell)
        end)
        animation:on_frame(4, function()
            spawn_next()
        end, true)
        animation:on_complete(function()
            --spell:erase()
        end)
        spell.on_update_func = function()
            local entitiesOnTile = spell:current_tile():find_characters(function(entity)
                if not entity:hittable() then return false end
                return true
            end)
            if (#entitiesOnTile > 0) then
                if (spell.current_entity == nil) then
                    local hitbox = Hitbox.new(spell:team())
                    hitbox:set_hit_props(laser_hit_props)
                    Field.spawn(hitbox, spell:current_tile())
                    spell.current_entity = entitiesOnTile[1]
                    battle_helpers.spawn_visual_artifact(spell:get_tile(), effects_texture,
                        effects_anim
                        , "ELEC"
                        , 0, 0)
                    Resources.play_audio(hit_sfx, AudioBehavior.Default)
                end
            else
                spell.current_entity = nil
            end
        end
        if tile == nil or tile:is_edge() then return end
        table.insert(owner.laserspells, spell)
        Field.spawn(spell, tile)
    end
    spawn_next()
end

--
function isForwardDirection(dir)
    -- check if direction is forward
    local returnval = (dir == Direction.Left or dir == Direction.Right)
    return returnval
end

function isUpDirection(dir)
    -- check if direction contains up
    return dir == Direction.UpLeft or dir == Direction.UpRight
end

function isDownDirection(dir)
    -- check if direction contains down
    return dir == Direction.DownLeft or dir == Direction.DownRight
end

function getNextTile(direction, spell)
    local tile = spell:current_tile():get_tile(direction, 1)
    return tile;
end

function tiletostring(tile)
    return "Tile: [" .. tostring(tile:x()) .. "," .. tostring(tile:y()) .. "]"
end

return character_init
