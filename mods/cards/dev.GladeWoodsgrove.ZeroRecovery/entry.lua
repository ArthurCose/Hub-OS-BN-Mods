local bn_helpers = require("dev.GladeWoodsgrove.BattleNetworkHelpers")

local TEXTURE = bn_helpers.load_texture("recover.png")
local ANIMATION = bn_helpers.fetch_animation_path("recover.animation")
local AUDIO = bn_helpers.load_audio("recover.ogg")

function card_init(user, props)
    local action = Action.new(user, "PLAYER_IDLE")

    action.on_execute_func = function(self)
        local recov = create_recov(user)
        user:field():spawn(recov, user:current_tile())
        print(props.recover)
        user:set_health(user:health() + props.recover)
        self:end_action()
    end

    return action
end

function create_recov(user)
    local artifact = Artifact.new()
    artifact:set_texture(TEXTURE)
    artifact:set_facing(user:facing())
    artifact:sprite():set_layer(-1)

    local anim = artifact:animation()
    anim:load(ANIMATION)
    anim:set_state("DEFAULT")
    anim:on_complete(function()
        artifact:erase()
    end)

    Resources.play_audio(AUDIO)

    return artifact
end
