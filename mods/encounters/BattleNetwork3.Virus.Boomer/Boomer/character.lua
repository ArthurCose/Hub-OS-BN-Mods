-- Imports
-- BattleHelper
local battle_helpers = require("battle_helpers.lua")
local panelgrab_chip = require("PanelGrab/entry.lua")
-- Animations, Textures and Sounds
local CHARACTER_ANIMATION = "battle.animation"
local CHARACTER_TEXTURE = Resources.load_texture("battle.greyscaled.png")
local BOOMERANG_SOUND = Resources.load_audio("boomer.ogg")
local BOOMERANG_SPRITE = Resources.load_texture("boomer.png")
local BOOMERANG_ANIM = "boomer.animation"
local effects_texture = Resources.load_texture("effect.png")
local effects_anim = "effect.animation"

--possible states for character
local states = { IDLE = 1, MOVE = 2, WAIT = 3 }
function character_init(self, character_info)
    -- Required function, main package information
    -- Load extra resources
    local base_animation_path = CHARACTER_ANIMATION
    self:set_texture(CHARACTER_TEXTURE)
    self.animation = self:animation()
    self.animation:load(base_animation_path)

    -- Set up character meta
    self:set_name(character_info.name)
    self:set_health(character_info.hp)
    self:set_height(character_info.height)
    self.damage = (character_info.damage)
    self:enable_sharing_tile(false)
    -- self:set_explosion_behavior(4, 1, false)
    self:set_offset(0 * 0.5, 0 * 0.5)
    self:set_palette(Resources.load_texture(character_info.palette))
    self.shockwave_anim = character_info.shockwave_anim
    self.panelgrabs = character_info.panelgrabs
    self.boomer_speed = character_info.boomer_speed
    self.animation:set_state("SPAWN")
    self.frame_counter = 0
    self.started = false
    self.idle_frames = 45
    --Select Boomer move direction
    self.move_direction = Direction.Up
    self.move_speed = character_info.move_speed
    self.defense = DefenseVirusBody.new()
    self:add_defense_rule(self.defense)
    self.reached_edge = false
    self.has_attacked_once = false
    self.guard = true
    self.end_wait = false

    self:ignore_hole_tiles(true)
    self:ignore_negative_tile_effects(true)

    self.defense_rule = DefenseRule.new(DefensePriority.Last, DefenseOrder.Always)
    local defense_texture = Resources.load_texture("guard_hit.png")
    local defense_animation = "guard_hit.animation"
    local defense_audio = Resources.load_audio("tink.ogg")
    self.defense_rule.can_block_func = function(judge, attacker, defender)
        local attacker_hit_props = attacker:copy_hit_props()

        if (self.guard) then
            if attacker_hit_props.flags & Hit.PierceGuard ~= 0 then
                --cant block breaking hits
                return
            end
            if attacker_hit_props.flags & Hit.Impact == 0 then
                --cant block non impact hits
                return
            end
            judge:block_impact()
            judge:block_damage()
            local artifact = Spell.new(self:team())
            artifact:set_texture(defense_texture)
            local anim = artifact:animation()
            anim:load(defense_animation)
            anim:set_state("DEFAULT")
            anim:apply(artifact:sprite())
            anim:on_complete(function()
                artifact:erase()
            end)
            self:field():spawn(artifact, self:get_tile())
            Resources.play_audio(defense_audio, AudioBehavior.Default)
        end
    end
    self:add_defense_rule(self.defense_rule)


    ---state idle

    self.action_idle = function(frame)
        if (frame == self.idle_frames) then
            ---choose move direction.
            self.animation:set_state("IDLE")
            self.animation:set_playback(Playback.Loop)
            self.end_wait = false
            self.turn()
        end
    end

    self.turn = function()
        self.move_direction = Direction.reverse(self.move_direction)

        self.set_state(states.MOVE)
    end

    ---state move

    self.action_move = function(frame)
        if (frame == 1) then
            local target_tile = self:get_tile(self.move_direction, 1)
            if (not self:can_move_to(target_tile)) then
                if (target_tile:is_edge()) then
                    self.reached_edge = true
                elseif (not self:can_move_to(self:get_tile(Direction.Up, 1)) and
                        not self:can_move_to(self:get_tile(Direction.Down, 1))) then
                    --detect if stuck
                    self.reached_edge = true
                else
                    self.turn()
                end
            end
            self:slide(target_tile, self.move_speed, 0, ActionOrder.Immediate, nil)
        end
        if (frame > 2 and not self:is_sliding()) then
            if (self.reached_edge) then
                -- if at the edge(or stuck), throw boomerang
                self.throw_boomerang()
                self.set_state(states.WAIT)
                self.reached_edge = false
            else
                -- keep moving to edge.
                if (self:get_tile():y() == 2 and self.has_attacked_once and self.panelgrabs > 0) then
                    local grab = panelgrab_chip.card_init(self)
                    self:queue_action(grab, ActionOrder.Involuntary)
                    self.panelgrabs = self.panelgrabs - 1
                    self.has_attacked_once = false
                end
                self.set_state(states.MOVE)
                self.reached_edge = false
            end
        end
    end

    ---state wait

    self.action_wait = function(frame)
        if (not self.end_wait) then
            self.wait_frame_counter = 0
        end
        if (frame == 12) then
            self:set_counterable(false)
        end
        self.wait_frame_counter = self.wait_frame_counter + 1
        if (self.wait_frame_counter == 60) then
            self.animation:set_state("RECOVER")
            self.set_state(states.IDLE)
            self.guard = true
        end
    end

    --utility to set the update state, and reset frame counter

    self.set_state = function(state)
        self.state = state
        self.frame_counter = 0
    end

    local actions = { [1] = self.action_idle, [2] = self.action_move, [3] = self.action_wait }

    self.on_update_func = function()
        self.frame_counter = self.frame_counter + 1
        if not self.started then
            --- this runs once the battle is started
            self.current_direction = self:facing()
            self.started = true
            self.set_state(states.IDLE)
        else
            --- On every frame, we will call the state action func.
            local action_func = actions[self.state]
            action_func(self.frame_counter)
        end
    end

    self.throw_boomerang = function()
        self.animation:set_state("THROW")

        self.has_attacked_once = true
        self.animation:on_frame(3, function()
            self.guard = false
            self:set_counterable(true)
        end)
        self.animation:on_complete(function()
            Resources.play_audio(BOOMERANG_SOUND, AudioBehavior.Default)
            boomerang(self)

            self.set_state(states.WAIT)
            self.animation:set_state("WAIT")
            self.animation:set_playback(Playback.Loop)
            self.end_wait = false
        end)
    end

    function Tiletostring(tile)
        return "Tile: [" .. tostring(tile:x()) .. "," .. tostring(tile:y()) .. "]"
    end

    ---Boomerang!

    function boomerang(user)
        local field = user:field()
        local spell = Spell.new(user:team())
        local spell_animation = spell:animation()
        local start_tile = user:get_tile(user:facing(), 1)
        -- Spell Hit Properties
        spell:set_hit_props(
            HitProps.new(
                user.damage,
                Hit.Impact | Hit.Flinch,
                Element.Wood,
                user:context(),
                Drag.None
            )
        )
        spell:set_facing(user:facing())
        spell_animation:load(BOOMERANG_ANIM)
        spell_animation:set_state("DEFAULT")
        spell_animation:set_playback(Playback.Loop)
        spell:set_texture(BOOMERANG_SPRITE)
        spell_animation:apply(spell:sprite())
        spell:sprite():set_layer(-2)
        -- Starting direction is user's facing
        spell.direction = user:facing()
        spell.userfacing = user:facing()
        spell.boomer_speed = user.boomer_speed
        spell.on_update_func = function()
            spell:current_tile():attack_entities(spell)

            if spell:is_moving() then
                return
            end

            local next_tile = spell:get_tile(spell.direction, 1)

            if not next_tile then
                spell:erase()

                if not user:deleted() then
                    user.animation:on_complete(function()
                        user.end_wait = true
                    end)
                end

                return
            end

            if next_tile:is_edge() then
                ---need to change a direction.
                if (spell.direction == Direction.Left or spell.direction == Direction.Right) then
                    if spell.direction == spell.userfacing then
                        --next direction is up or down
                        spell.direction = get_free_direction(spell:current_tile(), Direction.Up, Direction.Down)
                    end
                else
                    if (spell.direction == Direction.Up or spell.direction == Direction.Down) then
                        --next direction is left or right
                        spell.direction = get_free_direction(spell:current_tile(), Direction.Left, Direction.Right)
                    end
                end

                next_tile = spell:get_tile(spell.direction, 1)
            end

            spell:slide(next_tile, spell.boomer_speed)
        end
        spell.on_attack_func = function()
            battle_helpers.spawn_visual_artifact(spell:field(), spell:get_tile(), effects_texture, effects_anim, "WOOD"
            , 0, 0)
        end
        spell.on_delete_func = function()
            spell:erase()
        end
        field:spawn(spell, start_tile)
    end
end

---Checks if the tile in 2 given directions is free and returns that direction
function get_free_direction(tile, direction1, direction2)
    if (not tile:get_tile(direction1, 1):is_edge()) then
        return direction1
    else
        return direction2
    end
end

return character_init
