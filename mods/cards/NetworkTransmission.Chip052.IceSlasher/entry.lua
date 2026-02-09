local bn_assets = require("BattleNetwork.Assets")
local chip_audio = bn_assets.load_audio("IceBreath.ogg")
local texture = bn_assets.load_texture("satellite_blast.png")
local anim_path = bn_assets.fetch_animation_path("satellite_blast.animation")

function card_init(user, props)
    local action = Action.new(user, "CHARACTER_SWING_HAND")
    action:on_anim_frame(2, function()
        local spell = Spell.new(user:team())
        local sprite = spell:sprite()
        local anim = spell:animation()
        sprite:set_texture(texture)
        anim:load(anim_path)
        anim:set_state("FORWARD_BLUE")
        anim:set_playback(Playback.Loop)

        local facing = user:facing()
        spell:set_facing(facing)

        spell:set_elevation(user:height() / 2)

        local distance = 3

        spell:set_hit_props(HitProps.from_card(props, user:context(), Drag.None))

        spell.on_spawn_func = function()
            Resources.play_audio(chip_audio)
        end

        spell.on_collision_func = function(self, other)
            local hitparticle = bn_assets.HitParticle.new("AQUA", math.random(-1, 1), math.random(-1, 1))
            Field.spawn(hitparticle, other:current_tile())
        end

        spell.on_update_func = function(self)
            self:attack_tile()

            if self:is_moving() then return end

            if distance == 0 or self:current_tile():is_edge() then
                self:delete()
                return
            end

            local dest = self:get_tile(self:facing(), 1)
            self:slide(dest, 6, function()
                distance = distance - 1
            end)
        end

        Field.spawn(spell, user:get_tile(facing, 1))
    end)

    return action
end
