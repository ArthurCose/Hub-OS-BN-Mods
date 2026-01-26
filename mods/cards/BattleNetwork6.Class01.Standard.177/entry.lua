local TEXTURE = Resources.load_texture("artifact.png")
local AUDIO = Resources.load_audio("sfx.ogg")

function card_init(user)
    local action = Action.new(user)
    action:set_lockout(ActionLockout.new_async(20))

    action.on_execute_func = function()
        local busterup = create_busterup(user)
        Field.spawn(busterup, user:current_tile())
        user:boost_attack_level(1)
    end

    return action
end

function create_busterup(user)
    local artifact = Artifact.new()
    artifact:set_texture(TEXTURE)
    artifact:set_facing(user:facing())
    artifact:sprite():set_layer(-1)

    local anim = artifact:animation()
    anim:load("artifact.animation")
    anim:set_state("DEFAULT")
    anim:on_complete(function() artifact:erase() end)

    Resources.play_audio(AUDIO)

    return artifact
end
