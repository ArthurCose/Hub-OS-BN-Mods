local bn_assets = require("BattleNetwork.Assets")

local arrow_texture = bn_assets.load_texture("roll_arrow.png")
local bow_texture = bn_assets.load_texture("bn4_bow_roll.png")

local buster_anim_path = bn_assets.fetch_animation_path("bn4_bow_roll.animation")

local RECOVER_TEXTURE = bn_assets.load_texture("recover.png")
local RECOVER_ANIMATION = bn_assets.fetch_animation_path("recover.animation")
local RECOVER_AUDIO = bn_assets.load_audio("recover.ogg")

local function create_recov(user)
    local artifact = Artifact.new()
    artifact:set_texture(RECOVER_TEXTURE)
    artifact:set_facing(user:facing())
    artifact:sprite():set_layer(-1)

    local anim = artifact:animation()
    anim:load(RECOVER_ANIMATION)
    anim:set_state("DEFAULT")
    anim:on_complete(function()
        artifact:erase()
    end)

    Resources.play_audio(RECOVER_AUDIO)

    return artifact
end

function card_init(player, props)
    local action = Action.new(player, "CHARACTER_SHOOT")
    action:set_lockout(ActionLockout.new_animation())
    action.on_execute_func = function(self, user)
        local facing = user:facing()
        local do_attack = function()
            local spell = Spell.new(user:team())
            spell:set_facing(facing)
            spell:set_offset(-15, -41)
            spell:set_texture(arrow_texture)

            local direction = facing
            spell:set_hit_props(
                HitProps.from_card(
                    props,
                    user:context(),
                    Drag.None
                )
            )

            spell.on_update_func = function(self)
                local tile = self:current_tile()
                tile:attack_entities(self)

                if self:is_sliding() then return end

                if tile:is_edge() then
                    self:erase()
                    return
                end

                local dest = self:get_tile(direction, 1)
                self:slide(dest, 6)
            end

            spell.on_attack_func = function(self, other)
                local recover = create_recov(user)
                recover.on_spawn_func = function()
                    user:set_health(math.min(user:max_health(), user:health() + props.damage))
                end

                Field.spawn(recover, user:current_tile())
            end

            spell.on_collision_func = function(self, other)
                self:erase();
            end

            spell:set_tile_highlight(Highlight.Solid)

            spell.can_move_to_func = function(tile)
                return true
            end

            Field.spawn(spell, user:get_tile(facing, 1))
        end
        self:on_anim_frame(2, do_attack)
        self:on_anim_frame(1, function()
            local buster = self:create_attachment("BUSTER")
            local buster_sprite = buster:sprite()
            buster_sprite:set_texture(bow_texture)
            buster_sprite:set_layer(-1)
            buster_sprite:use_root_shader()

            local buster_anim = buster:animation()
            buster_anim:load(buster_anim_path)
            buster_anim:set_state("FIRE")
        end)
    end
    return action
end
