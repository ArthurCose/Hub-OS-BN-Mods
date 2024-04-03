local ParticlePoof = {}

local TEXTURE = Resources.load_texture("poof.png")

ParticlePoof.new = function()
    local fx = Artifact.new()
    fx:set_texture(TEXTURE)

    local fx_animation = fx:animation()
    fx_animation:load("poof.animation")
    fx_animation:set_state("DEFAULT")
    fx_animation:on_complete(function()
        fx:erase()
    end)

    return fx;
end

return ParticlePoof