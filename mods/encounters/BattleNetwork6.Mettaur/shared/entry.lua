---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
---@type dev.konstinople.library.turn_based
local TurnBasedLib = require("dev.konstinople.library.turn_based")

local battle_helpers = require("battle_helpers.lua")

local wave_texture = Resources.load_texture("shockwave.png")
local wave_sfx = bn_assets.load_audio("shockwave.ogg")
local teleport_animation_path = "teleport.animation"
local teleport_texture_path = "teleport.png"
local teleport_texture = Resources.load_texture(teleport_texture_path)
local guard_hit_effect_texture = Resources.load_texture("guard_hit.png")
local guard_hit_effect_animation_path = "guard_hit.animation"
local tink_sfx = bn_assets.load_audio("guard.ogg")

local function debug_print(text)
    --print("[mettaur] " .. text)
end

local turn_tracker = TurnBasedLib.new_directional_tracker()

local TEXTURE = Resources.load_texture("battle.greyscaled.png")

function character_init(self, character_info)
    debug_print("character_init called")
    -- Required function, main package information

    -- Load character resources
    local animation = self:animation()
    animation:load("battle.animation")

    -- Load extra resources

    -- Set up character meta
    self:set_name(character_info.name)
    self:set_health(character_info.hp)
    self:set_texture(TEXTURE)
    self:set_height(character_info.height)
    self:enable_sharing_tile(false)
    self:set_palette(Resources.load_texture(character_info.palette))

    --defense rules
    self:add_aux_prop(StandardEnemyAux.new())

    -- Initial state
    animation:set_state("IDLE")
    animation:set_playback(Playback.Loop)
    self.frames_between_actions = character_info.move_delay
    self.cascade_frame_index = character_info.cascade_frame --lower = faster shockwaves
    self.shockwave_animation = character_info.shockwave_animation
    self.shockwave_damage = character_info.damage
    self.can_guard = character_info.can_guard
    self.replacement_panel = character_info.replacement_panel
    self.ai_wait = self.frames_between_actions
    self.ai_taken_turn = false

    self.on_idle_func = function()
        animation:set_state("IDLE")
        animation:set_playback(Playback.Loop)
    end

    self.on_update_func = function(self)
        if turn_tracker:request_turn(self) then
            take_turn(self)
        else
            idle_action(self)
        end
    end

    self.on_battle_start_func = function(self)
        debug_print("battle_start_func called")
        ---@param a Entity
        ---@param b Entity
        local mob_sort_func = function(a, b)
            local met_a_tile = a:current_tile()
            local met_b_tile = b:current_tile()
            local var_a = (met_a_tile:x() * 3) + met_a_tile:y()
            local var_b = (met_b_tile:x() * 3) + met_b_tile:y()
            return var_a < var_b
        end
        turn_tracker:sort_turn_order(mob_sort_func)
        turn_tracker:sort_turn_order(function(a, b)
            -- reversed sort direction
            return mob_sort_func(b, a)
        end)
    end
    self.on_spawn_func = function(self)
        debug_print("on_spawn_func called")
        turn_tracker:add_entity(self)
    end
end

function find_target(self)
    local team = self:team()
    local target_list = Field.find_characters(function(entity)
        if not entity:hittable() then return false end

        return entity:team() ~= team
    end)
    if #target_list == 0 then
        debug_print("No targets found!")
        return
    end
    local target_character = target_list[1]
    return target_character
end

function idle_action(self)
    if self.can_guard then
        --if the mettaur can guard, queue up a guard for after the current action
        if self.guarding_defense_rule then
            local anim = self:animation()
            anim:set_state("GUARD_PERSIST")
        elseif not self.guard_transition then
            begin_guard(self)
        end
    end
end

function end_guard(character)
    character.guard_transition = true
    local anim = character:animation()
    anim:set_state("GUARD_END")
    anim:set_playback(Playback.Once)
    character:remove_defense_rule(character.guarding_defense_rule)
    character.guarding_defense_rule = nil
    anim:on_complete(function()
        character.guard_transition = false
    end)
end

function begin_guard(character)
    character.guard_transition = true
    local anim = character:animation()
    anim:set_state("GUARD_START")
    anim:set_playback(Playback.Once)

    anim:on_complete(function()
        character.guard_transition = false
        character.guarding_defense_rule = DefenseRule.new(DefensePriority.Last, DefenseOrder.Always)
        character.guarding_defense_rule.defense_func = function(defense, attacker, defender, attacker_hit_props)
            if attacker_hit_props.flags & Hit.Drain ~= 0 or attacker_hit_props.flags & Hit.PierceGuard ~= 0 then
                --cant block breaking hits with guard
                return
            end
            defense:set_responded()
            defense:block_damage()
            if attacker_hit_props.damage > 0 then
                Resources.play_audio(tink_sfx, AudioBehavior.Default)
                battle_helpers.spawn_visual_artifact(character, character:current_tile(), guard_hit_effect_texture,
                    guard_hit_effect_animation_path, "DEFAULT", 0, -30)
            end
        end
        character:add_defense_rule(character.guarding_defense_rule)
    end)
end

function take_turn(self)
    if self.ai_wait > 0 or self.ai_taken_turn then
        self.ai_wait = self.ai_wait - 1
        if not self.guarding_defense_rule and not self.guard_transition and not self.shockwave_action then
            local anim = self:animation()
            anim:set_state("IDLE")
        end
        return
    end
    self.ai_taken_turn = true

    if self.guarding_defense_rule and not self.guard_transition then
        self.ai_wait = self.frames_between_actions
        self.ai_taken_turn = false
        end_guard(self)
        return
    end

    local moved = move_towards_character(self)
    if moved then
        self.ai_wait = self.frames_between_actions
        self.ai_taken_turn = false
        return
    end
    self.shockwave_action = action_shockwave(self)
    self.shockwave_action.on_action_end_func = function()
        self.ai_wait = self.frames_between_actions
        self.ai_taken_turn = false
        self.shockwave_action = nil
        turn_tracker:end_turn(self)
    end
    self:queue_action(self.shockwave_action)
end

function move_towards_character(self)
    local target_character = find_target(self)
    if not target_character then return false end

    local target_character_tile = target_character:current_tile()
    local tile = self:current_tile()
    local target_movement_tile = nil
    if tile:y() < target_character_tile:y() then
        target_movement_tile = tile:get_tile(Direction.Down, 1)
    end
    if tile:y() > target_character_tile:y() then
        target_movement_tile = tile:get_tile(Direction.Up, 1)
    end
    if not target_movement_tile or not self:can_move_to(target_movement_tile) then
        return false
    end

    local artifact = battle_helpers.spawn_visual_artifact(self, tile, teleport_texture, teleport_animation_path,
        "MEDIUM_TELEPORT_FROM", 0, -self:height())
    artifact:sprite():set_layer(-1)
    artifact:animation():on_frame(2, function()
        self:teleport(target_movement_tile)
    end)

    return true
end

function action_shockwave(character)
    local action_name = "shockwave"
    local facing = character:facing()
    debug_print('action ' .. action_name)

    local action = Action.new(character, "ATTACK")
    action:set_lockout(ActionLockout.new_animation())
    action.on_execute_func = function(self, user)
        self:on_anim_frame(6, function()
            character:set_counterable(true)
        end)
        self:on_anim_frame(12, function()
            local tile = character:get_tile(facing, 1)
            spawn_shockwave(character, tile, facing, character.shockwave_damage, wave_texture,
                character.shockwave_animation, wave_sfx, character.cascade_frame_index, character.replacement_panel)
        end)
        self:on_anim_frame(13, function()
            character:set_counterable(false)
        end)
    end
    return action
end

function spawn_shockwave(owner, tile, direction, damage, wave_texture, wave_animation, wave_sfx, cascade_frame_index,
                         new_tile_state)
    local team = owner:team()
    local cascade_frame = cascade_frame_index
    local spawn_next
    spawn_next = function()
        if not tile:is_walkable() then return end

        Resources.play_audio(wave_sfx, AudioBehavior.Default)

        local spell = Spell.new(team)
        spell:set_facing(direction)
        spell:set_tile_highlight(Highlight.Solid)
        spell:set_hit_props(HitProps.new(
            damage,
            Hit.Flinch | Hit.Flash,
            Element.None,
            owner:context(),
            Drag.new()
        ))

        local sprite = spell:sprite()
        sprite:set_texture(wave_texture)
        sprite:set_layer(-1)

        local animation = spell:animation()
        animation:load(wave_animation)
        animation:set_state("DEFAULT")
        animation:apply(sprite)

        animation:on_frame(cascade_frame, function()
            tile = tile:get_tile(direction, 1)
            spawn_next()
        end, true)
        animation:on_complete(function() spell:erase() end)

        spell.on_update_func = function()
            spell:current_tile():attack_entities(spell)
            if new_tile_state then
                spell:current_tile():set_state(new_tile_state)
            end
        end

        Field.spawn(spell, tile)
    end

    spawn_next()
end

return character_init
