---@type dev.konstinople.library.ai
local Ai = require("dev.konstinople.library.ai")
---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

local METEOR_TEXTURE = bn_assets.load_texture("meteor.png")
local METEOR_ANIM_PATH = bn_assets.fetch_animation_path("meteor.animation")
local EXPLOSION_TEXTURE = bn_assets.load_texture("ring_explosion.png")
local EXPLOSION_ANIM_PATH = bn_assets.fetch_animation_path("ring_explosion.animation")
local EXPLOSION_SFX = bn_assets.load_audio("explosion_defeatedboss")
local LANDING_SFX = bn_assets.load_audio("meteor_land.ogg")

local MobTracker = require("mob_tracker.lua")
local mob_tracker = MobTracker:new()

local attack = 0
local cooldown = 16
local minimum_meteors = 4
local maximum_meteors = 8
local meteor_cooldown = 0
local accuracy_chance = 0
local idle_max = 40

---@class Metrid : Entity
---@field _attack number
---@field _minimum_meteors number
---@field _maximum_meteors number
---@field _meteor_cooldown number
---@field _accuracy_chance number

---@param metrid Metrid
local function create_meteor(metrid)
    local meteor = Spell.new(metrid:team())
    meteor:set_tile_highlight(Highlight.Flash)
    meteor:set_facing(metrid:facing())
    local flags = Hit.Flash | Hit.Flinch | Hit.PierceGround

    if metrid:rank() == Rank.NM then
        flags = flags & ~Hit.Flash
    end

    meteor:set_hit_props(
        HitProps.new(
            attack,
            flags,
            Element.Fire,
            metrid:context(),
            Drag.None
        )
    )
    meteor:set_texture(METEOR_TEXTURE)
    local anim = meteor:animation()
    anim:load(METEOR_ANIM_PATH)
    anim:set_state("DEFAULT")
    anim:apply(meteor:sprite())
    meteor:sprite():set_layer(-2)
    local boom = EXPLOSION_TEXTURE

    local increment_x = 7
    local increment_y = 7
    meteor:set_offset(meteor:offset().x + 112, meteor:offset().y - 112)
    meteor.on_update_func = function(self)
        if cooldown <= 0 then
            local tile = self:current_tile()
            if tile and tile:is_walkable() then
                tile:attack_entities(self)
                Field.shake(5, 18)
                local explosion = Spell.new(self:team())
                explosion:set_texture(boom)
                local new_anim = explosion:animation()
                new_anim:load(EXPLOSION_ANIM_PATH)
                new_anim:set_state("DEFAULT")
                new_anim:apply(explosion:sprite())
                explosion:sprite():set_layer(-2)
                Resources.play_audio(LANDING_SFX)
                Field.spawn(explosion, tile)
                new_anim:on_frame(3, function()
                    Resources.play_audio(EXPLOSION_SFX)
                end)
                new_anim:on_complete(function()
                    explosion:erase()
                end)
            end
            self:erase()
        else
            local offset = self:offset()
            self:set_offset(offset.x - increment_x, offset.y + increment_y)
            cooldown = cooldown - 1
        end
    end
    meteor.can_move_to_func = function(tile)
        return true
    end
    return meteor
end

local function find_best_target(virus)
    if not virus or virus and virus:deleted() then return end
    local target
    local query = function(c)
        --Make sure you're not targeting the same team, since that won't work for an attack.
        return c:team() ~= virus:team() or c:team() == Team.Other
    end

    --Find CHARACTERS, not entities, to attack.
    local potential_threats = Field.find_characters(query)

    --Start with a ridiculous health.
    local goal_hp = 999999

    --If the list is bigger than 0, we go in to a loop.
    if #potential_threats > 0 then
        --The pound sign, or hashtag if you're more familiar with that term, is used to denote length of a list or array in lua.
        for i = 1, #potential_threats, 1 do
            --Index with square brackets.
            local possible_target = potential_threats[i]

            --Make sure it has less health than the goal HP. First one always will meet this requirement.
            if possible_target:health() <= goal_hp then
                --Make it the new target. This way the lowest HP target is attacked.
                target = possible_target
            end
        end
    end

    --Return whoever we get.
    return target
end

---@param metrid Metrid
local function create_meteor_action(metrid)
    local action = Action.new(metrid)
    action:set_lockout(ActionLockout.new_sequence())
    local init_step = action:create_step()
    local meteor_step = action:create_step()

    local metrid_anim = metrid:animation()

    local function create_component()
        local meteor_component = metrid:create_component(Lifetime.ActiveBattle)
        local count = math.random(minimum_meteors, maximum_meteors)
        local attack_cooldown_max = meteor_cooldown
        local highlight_cooldown_max = 24
        local highlight_cooldown = 24
        local attack_cooldown = 0
        local desired_cooldown = 0
        local next_tile = nil

        if metrid:rank() == Rank.NM then
            desired_cooldown = attack_cooldown_max - 16
        end

        meteor_component.on_update_func = function()
            if metrid:deleted() then return end
            if count <= 0 then
                metrid_anim:set_state("DRESS")
                metrid_anim:on_complete(function()
                    mob_tracker:advance_a_turn()
                    meteor_step:complete_step()
                end)
                meteor_component:eject()
                return
            end

            if next_tile ~= nil then
                next_tile:set_highlight(Highlight.Flash)
            end

            if highlight_cooldown <= 0 then
                local tile_list = Field.find_tiles(function(tile)
                    return tile:team() ~= metrid:team() and tile:is_walkable()
                end)

                --Use less than or equal to copmarison to confirm a d100 roll of accuracy.
                --Example: if a Metrid has an accuracy chance of 20, then a 1 to 100 roll will
                --Only target the player's tile on a roll of 1-20, leading to an 80% chance of
                --Targeting a random player tile.
                if math.random(1, 100) <= accuracy_chance then
                    local target = find_best_target(metrid)
                    if target ~= nil then
                        next_tile = target:current_tile()
                    else
                        next_tile = tile_list[math.random(1, #tile_list)]
                    end
                else
                    next_tile = tile_list[math.random(1, #tile_list)]
                end
                highlight_cooldown = highlight_cooldown_max
            else
                highlight_cooldown = highlight_cooldown - 1
            end

            if attack_cooldown <= desired_cooldown and next_tile ~= nil then
                count = count - 1
                attack_cooldown_max = attack_cooldown_max
                attack_cooldown = attack_cooldown_max
                Field.spawn(create_meteor(metrid), next_tile)
            else
                attack_cooldown = attack_cooldown - 1
            end
        end
    end

    action.on_execute_func = function()
        metrid_anim:set_state("DISROBE")
        metrid_anim:on_complete(function()
            metrid_anim:set_state("ATTACK")
            metrid_anim:set_playback(Playback.Loop)
            init_step:complete_step()
            create_component()
        end)
    end

    return action
end

---@param entity Entity
local function default_random_tile(entity)
    local tiles = Field.find_tiles(function(tile)
        return entity:can_move_to(tile) and tile ~= entity:current_tile()
    end)

    if #tiles == 0 then
        return nil
    end

    return tiles[math.random(#tiles)]
end

---@param entity Entity
local function create_move_factory(entity)
    local function target_tile_callback()
        local tile = default_random_tile(entity)
        if tile then
            entity:set_facing(tile:facing())
            return tile
        end
    end

    return function()
        return bn_assets.MobMoveAction.new(entity, "MEDIUM", target_tile_callback)
    end
end

---@param metrid Entity
local function setup_random_tile(metrid)
    local preferred_tiles = Field.find_tiles(function(tile)
        if not metrid:can_move_to(tile) then
            return false
        end

        local forward_tile = tile:get_tile(tile:facing(), 1)
        if not forward_tile then
            return false
        end

        local has_obstacle
        forward_tile:find_obstacles(function()
            has_obstacle = true
            return false
        end)

        return has_obstacle
    end)

    if #preferred_tiles ~= 0 then
        return preferred_tiles[math.random(#preferred_tiles)]
    end

    local tiles = Field.find_tiles(function(tile)
        return metrid:can_move_to(tile)
    end)

    if #tiles ~= 0 then
        return tiles[math.random(#tiles)]
    end

    return nil
end

---@param entity Entity
local function create_setup_factory(entity)
    local function target_tile_callback()
        local tile = setup_random_tile(entity)
        if tile then
            entity:set_facing(tile:facing())
            return tile
        end
    end

    return function()
        return bn_assets.MobMoveAction.new(entity, "MEDIUM", target_tile_callback)
    end
end

---@param self Metrid
function character_init(self)
    self:set_height(38)

    accuracy_chance = 20
    meteor_cooldown = 32

    attack = self._damage
    idle_max = self._idle_max
    minimum_meteors = self._minimum_meteors
    maximum_meteors = self._maximum_meteors
    accuracy_chance = self._accuracy_chance

    self:set_health(self._health)

    self:set_element(Element.Fire)

    self:add_aux_prop(StandardEnemyAux.new())

    local anim = self:animation()
    anim:load("Metrid.animation")
    anim:set_state("IDLE")
    anim:apply(self:sprite())
    anim:set_playback(Playback.Loop)

    self.on_battle_start_func = function()
        mob_tracker:add_by_id(self:id())
    end

    self.on_delete_func = function()
        mob_tracker:remove_by_id(self:id())
        self:default_character_delete()
    end

    self.on_idle_func = function()
        anim:set_state("IDLE")
        anim:set_playback(Playback.Loop)
    end

    local ai = Ai.new_ai(self)
    local plan = ai:create_plan()
    local move_factory = create_move_factory(self)
    local idle_factory = Ai.create_idle_action_factory(self, idle_max, idle_max)
    local setup_factory = create_setup_factory(self)
    local attack_factory = function()
        return create_meteor_action(self)
    end

    plan:set_action_iter_factory(function()
        return Ai.IteratorLib.chain(
            Ai.IteratorLib.flatten(Ai.IteratorLib.take(5, function()
                -- move + idle
                return Ai.IteratorLib.chain(
                    Ai.IteratorLib.take(1, move_factory),
                    Ai.IteratorLib.take(1, idle_factory)
                )
            end)),
            Ai.IteratorLib.flatten(Ai.IteratorLib.take(1, function()
                -- attempt attack

                if mob_tracker:get_active_mob() ~= self:id() then
                    -- not our turn, return empty iterator
                    return function() return nil end
                end

                -- setup + attack
                return Ai.IteratorLib.chain(
                    Ai.IteratorLib.take(1, setup_factory),
                    Ai.IteratorLib.take(1, idle_factory),
                    Ai.IteratorLib.take(1, attack_factory)
                )
            end))
        )
    end)
end

return character_init
