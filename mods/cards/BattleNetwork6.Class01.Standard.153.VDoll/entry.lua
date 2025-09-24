---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")

---@type BombLib
local BombLib = require("dev.konstinople.library.bomb")

local doll_texture = bn_assets.load_texture("vdoll.png")
local doll_anim_path = bn_assets.fetch_animation_path("vdoll.animation")

local pointer_texture = bn_assets.load_texture("pointer.png")
local pointer_anim_path = bn_assets.fetch_animation_path("pointer.animation")
local pointer_audio = bn_assets.load_audio("indicate.ogg")

local explosion_texture = bn_assets.load_texture("bn4_spell_explosion.png")
local explosion_anim_path = bn_assets.fetch_animation_path("bn4_spell_explosion.animation")
local explosion_sfx = bn_assets.load_audio("explosion_defeatedmob.ogg")

local pointer_animation = Animation.new(pointer_anim_path)

local bomb = BombLib.new_bomb()
bomb:set_bomb_texture(bn_assets.load_texture("bomb.png"))
bomb:set_bomb_animation_path(bn_assets.fetch_animation_path("bomb.animation"))
bomb:set_bomb_shadow(bn_assets.load_texture("bomb_shadow.png"))
bomb:set_execute_sfx(bn_assets.load_audio("lob_bomb.ogg"))
bomb:set_air_duration(67)

local function create_explosion(callback)
    local explosion = Artifact.new()
    explosion:set_texture(explosion_texture)
    explosion:set_layer(-1)
    explosion:set_offset(math.random(-16, 16), math.random(-16, 0))

    local explosion_anim = explosion:animation()
    explosion_anim:load(explosion_anim_path)
    explosion_anim:set_state("DARK")

    explosion_anim:on_frame(5, function()
        callback()
    end)

    explosion_anim:on_complete(function()
        explosion:delete()
    end)

    explosion.on_spawn_func = function()
        Resources.play_audio(explosion_sfx)
    end

    return explosion
end

local function create_explosion_attack(team, damage, callback)
    local spell = Spell.new(team)
    spell:set_hit_props(
        HitProps.new(
            math.min(2048, damage),
            Hit.PierceInvis,
            Element.None
        )
    )

    spell.on_spawn_func = function()
        spell:attack_tile()
        spell:delete()

        local tile = spell:current_tile()
        local explosion = create_explosion(function()
            local explosion = create_explosion(callback)
            Field.spawn(explosion, tile)
        end)
        Field.spawn(explosion, tile)
    end

    spell.on_collision_func = function(_, other)
        local particle = bn_assets.HitParticle.new("SPARK_1")
        local movement_offset = other:movement_offset()
        particle:set_offset(movement_offset.x + math.random(-8, 8), movement_offset.y + math.random(-8, 0))
        Field.spawn(particle, other:current_tile())
    end

    return spell
end

bomb.swap_bomb_func = function(action)
    local user = action:owner()

    local doll = Obstacle.new(Team.Other)
    doll:set_height(34)
    doll:set_health(2048)
    doll:set_owner(user)
    doll:enable_hitbox(true)
    doll:add_aux_prop(AuxProp.new():declare_immunity(~Hit.None))
    doll:set_texture(doll_texture)

    local doll_anim = doll:animation()
    doll_anim:load(doll_anim_path)
    doll_anim:set_state("IDLE")

    -- VDoll faces same way
    doll:set_facing(user:facing())

    -- VDoll does not flip based on tile but bsaed on user
    -- Ignore auto-flipping and defer to the set facing above
    doll:set_never_flip(true)
    doll:set_shadow(Shadow.Small)

    local timer = 420

    doll.on_update_func = function(self)
        local elevation = doll:elevation()

        if elevation < 16 and elevation > 0 then
            doll:attack_tile()
            doll:enable_hitbox()
        end

        if elevation > 0 then
            return
        end

        -- Don't count down if already set to erase
        if self:will_erase_eof() then return end

        -- Don't count down during time freeze
        if TurnGauge.frozen() then return end

        if timer == 0 then
            self:delete()
            return
        end

        timer = timer - 1
    end

    doll.on_collision_func = function()
        -- collided with something, delete
        doll:delete()
    end

    local curse_caster = Artifact.new(user:team())

    doll.on_spawn_func = function()
        Field.spawn(curse_caster, doll:current_tile())
    end

    doll.on_delete_func = function()
        local mob_move = bn_assets.MobMove.new("MEDIUM_END")
        local offset = doll:offset()
        local elevation = doll:elevation()
        mob_move:set_offset(offset.x, -doll:height() // 2 - elevation + offset.y)

        mob_move.on_spawn_func = function()
            doll:erase()
        end

        Field.spawn(mob_move, doll:current_tile())

        if not curse_caster:deleted() and not curse_caster:has_actions() then
            curse_caster:delete()
        end
    end

    local activated = false

    local curse_defense = DefenseRule.new(DefensePriority.Last, DefenseOrder.Always)
    curse_defense.defense_func = function(defense, attacker, defender, hit_props)
        if doll:elevation() > 0 then
            -- if we're hit while in the air, just delete
            doll:delete()
            return
        end

        if hit_props.flags & Hit.Drain == Hit.Drain then return end
        if defense:responded() or activated then return end

        defense:set_responded()
        activated = true

        local curse_action = Action.new(curse_caster)
        curse_action:set_lockout(ActionLockout.new_sequence())

        local action_props = CardProperties.new()
        action_props.short_name = "Curse"
        action_props.time_freeze = true
        action_props.prevent_time_freeze_counter = true
        action_props.damage = math.min(2048, hit_props.damage)

        curse_action:set_card_properties(action_props)

        curse_action.on_execute_func = function(self)
            -- reset animation
            pointer_animation:set_state("DEFAULT")
            pointer_animation:set_playback(Playback.Loop)

            -- create sprite
            local targets = Field.find_characters(function(e)
                return e:team() ~= curse_caster:team() and e:hittable()
            end)

            if #targets == 0 then
                self:end_action()
                return
            end

            local pointers = {}

            for i, target in ipairs(targets) do
                local pointer = target:create_node()
                pointer:set_never_flip(true)
                pointer:set_texture(pointer_texture)
                pointer_animation:apply(pointer)
                pointers[i] = pointer
            end

            -- create step to update the animation and wait for completion
            local step = curse_action:create_step()

            local loops = 0
            local attacking = false
            step.on_update_func = function()
                if attacking then return end
                pointer_animation:update()

                -- updating the pointer animation can trigger the on_complete callback
                if attacking then return end

                for _, pointer in ipairs(pointers) do
                    pointer_animation:apply(pointer)
                end
            end

            pointer_animation:on_complete(function()
                loops = loops + 1

                if loops ~= 4 then
                    Resources.play_audio(pointer_audio)
                    return
                end

                attacking = true

                local callback = function()
                    step:complete_step()
                end

                for i, target in ipairs(targets) do
                    local explosion = create_explosion_attack(user:team(), action_props.damage, callback)
                    Field.spawn(explosion, target:current_tile())

                    local pointer = pointers[i]
                    target:remove_node(pointer)
                end
            end)

            Resources.play_audio(pointer_audio)
        end

        curse_caster:queue_action(curse_action)
        doll:delete()
    end

    doll:add_defense_rule(curse_defense)
    doll:enable_hitbox(false)

    return doll
end

---@param user Entity
function card_init(user, props)
    return bomb:create_action(user, function(main_tile, doll)
        if not main_tile or not main_tile:is_walkable() then
            return
        end

        doll:enable_hitbox()
        main_tile:set_state(TileState.Poison)
    end)
end
