-- Imports
-- BattleHelper
local battle_helpers = require("battle_helpers.lua")
-- Animations, Textures and Sounds
local CHARACTER_ANIMATION = "battle.animation"
local CHARACTER_TEXTURE = Resources.load_texture("battle.greyscaled.png")
local BOOMERANG_SOUND = Resources.load_audio("boomer.ogg")
local BOOMERANG_SPRITE = Resources.load_texture("boomer.png")
local BOOMERANG_ANIM = "boomer.animation"
local effects_texture = Resources.load_texture("effect.png")
local effects_anim = "effect.animation"

---Checks if the tile in 2 given directions is free and returns that direction
local function get_free_direction(tile, direction1, direction2)
    if not tile:get_tile(direction1, 1):is_edge() then
        return direction1
    else
        return direction2
    end
end

--possible states for character
local states = { IDLE = 1, MOVE = 2, WAIT = 3 }
---Boomerang!

---@param user Entity
local function boomerang(user, character_info, callback)
    local start_tile = user:get_tile(user:facing(), 1)

    if not start_tile then
        return
    end

    local spell = Spell.new(user:team())
    spell:set_facing(user:facing())
    spell:set_texture(BOOMERANG_SPRITE)
    spell:sprite():set_layer(-2)

    local spell_animation = spell:animation()
    spell_animation:load(BOOMERANG_ANIM)
    spell_animation:set_state("DEFAULT")
    spell_animation:set_playback(Playback.Loop)

    -- Spell Hit Properties
    spell:set_hit_props(
        HitProps.new(
            character_info.damage,
            Hit.Flinch,
            Element.Wood,
            user:context(),
            Drag.None
        )
    )

    -- Starting direction is user's facing
    local direction = user:facing()
    local userfacing = user:facing()
    spell.on_update_func = function()
        spell:current_tile():attack_entities(spell)

        if spell:is_moving() then
            return
        end

        local next_tile = spell:get_tile(direction, 1)

        if not next_tile then
            spell:erase()
            callback()
            return
        end

        if next_tile:is_edge() then
            ---need to change a direction.
            if (direction == Direction.Left or direction == Direction.Right) then
                if direction == userfacing then
                    --next direction is up or down
                    direction = get_free_direction(spell:current_tile(), Direction.Up, Direction.Down)
                end
            else
                if (direction == Direction.Up or direction == Direction.Down) then
                    --next direction is left or right
                    direction = get_free_direction(spell:current_tile(), Direction.Left, Direction.Right)
                end
            end

            next_tile = spell:get_tile(direction, 1)
        end

        spell:slide(next_tile, character_info.boomer_speed)
    end
    spell.on_attack_func = function()
        battle_helpers.spawn_visual_artifact(spell:get_tile(), effects_texture, effects_anim, "WOOD"
        , 0, 0)
    end
    spell.on_delete_func = function()
        spell:erase()
    end

    Field.spawn(spell, start_tile)
end

---@param self Entity
local function shared_character_init(self, character_info)
    -- Set up character meta
    self:set_name(character_info.name)
    self:set_health(character_info.hp)
    self:set_height(44)

    self:set_texture(CHARACTER_TEXTURE)

    local animation = self:animation()
    animation:load(CHARACTER_ANIMATION)
    animation:set_state("SPAWN")

    self:set_palette(Resources.load_texture(character_info.palette))

    local frame_counter = 0
    local started = false
    local idle_frames = 45
    local move_direction = Direction.Up
    local reached_edge = false
    local has_attacked_once = false
    local guarding = true
    local end_wait = false
    local state = states.IDLE

    -- set up defenses
    self:add_aux_prop(StandardEnemyAux.new())
    self:ignore_hole_tiles(true)
    self:ignore_negative_tile_effects(true)

    local defense_rule = DefenseRule.new(DefensePriority.Last, DefenseOrder.Always)
    local defense_texture = Resources.load_texture("guard_hit.png")
    local defense_animation = "guard_hit.animation"
    local defense_audio = Resources.load_audio("tink.ogg")
    defense_rule.defense_func = function(defense, attacker, defender)
        local attacker_hit_props = attacker:copy_hit_props()

        if guarding then
            if attacker_hit_props.flags & Hit.PierceGuard ~= 0 then
                --cant block breaking hits
                return
            end
            if attacker_hit_props.flags & Hit.Drain ~= 0 then
                --cant block non impact hits
                return
            end
            defense:set_responded()
            defense:block_damage()

            local artifact = Spell.new(self:team())
            artifact:set_texture(defense_texture)

            local anim = artifact:animation()
            anim:load(defense_animation)
            anim:set_state("DEFAULT")
            anim:apply(artifact:sprite())
            anim:on_complete(function()
                artifact:erase()
            end)

            Field.spawn(artifact, self:current_tile())

            Resources.play_audio(defense_audio, AudioBehavior.Default)
        end
    end

    self:add_defense_rule(defense_rule)

    --utility to set the update state, and reset frame counter
    local function set_state(s)
        state = s
        frame_counter = 0
    end

    ---state idle
    local function turn()
        move_direction = Direction.reverse(move_direction)

        set_state(states.MOVE)
    end

    local function action_idle(frame)
        if (frame == idle_frames) then
            ---choose move direction.
            animation:set_state("IDLE")
            animation:set_playback(Playback.Loop)
            end_wait = false
            turn()
        end
    end

    local throw_boomerang = function()
        animation:set_state("THROW")

        has_attacked_once = true

        animation:on_frame(3, function()
            guarding = false
            self:set_counterable(true)
        end)

        animation:on_complete(function()
            Resources.play_audio(BOOMERANG_SOUND, AudioBehavior.Default)
            boomerang(self, character_info, function()
                if not self:deleted() then
                    self:animation():on_complete(function()
                        end_wait = true
                    end)
                end
            end)

            set_state(states.WAIT)
            animation:set_state("WAIT")
            animation:set_playback(Playback.Loop)
            end_wait = false
        end)
    end

    ---state move

    local function action_move(frame)
        if (frame == 1) then
            local target_tile = self:get_tile(move_direction, 1)
            if (not self:can_move_to(target_tile)) then
                if not target_tile or target_tile:is_edge() then
                    reached_edge = true
                elseif (not self:can_move_to(self:get_tile(Direction.Up, 1)) and
                        not self:can_move_to(self:get_tile(Direction.Down, 1))) then
                    --detect if stuck
                    reached_edge = true
                else
                    turn()
                end
            end
            self:slide(target_tile, character_info.move_speed)
        end
        if (frame > 2 and not self:is_sliding()) then
            if reached_edge then
                -- if at the edge(or stuck), throw boomerang
                throw_boomerang()
                set_state(states.WAIT)
                reached_edge = false
            else
                -- try using a field card
                if self:get_tile():y() == 2 and has_attacked_once and self:field_card(1) then
                    local action = Action.from_card(self, self:field_card(1))
                    self:remove_field_card(1)

                    if action then
                        self:queue_action(action)
                    end

                    has_attacked_once = false
                end
                set_state(states.MOVE)
                reached_edge = false
            end
        end
    end

    ---state wait

    local wait_frame_counter = 0

    local action_wait = function(frame)
        if not end_wait then
            wait_frame_counter = 0
        end

        if frame == 12 then
            self:set_counterable(false)
        end

        wait_frame_counter = wait_frame_counter + 1

        if wait_frame_counter == 60 then
            animation:set_state("RECOVER")
            set_state(states.IDLE)
            guarding = true
        end
    end

    local actions = { action_idle, action_move, action_wait }

    self.on_update_func = function()
        if self:has_actions() then
            return
        end

        frame_counter = frame_counter + 1
        if not started then
            --- this runs once the battle is started
            started = true
            set_state(states.IDLE)
        else
            --- On every frame, we will call the state action func.
            local action_func = actions[state]
            action_func(frame_counter)
        end
    end
end

return shared_character_init
