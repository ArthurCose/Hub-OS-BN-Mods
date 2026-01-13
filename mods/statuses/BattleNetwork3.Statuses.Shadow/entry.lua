---@type BattleNetwork.Assets
local bn_assets = require("BattleNetwork.Assets")
local start_sound = bn_assets.load_audio("shadow_status.ogg")
local end_sound = bn_assets.load_audio("appear.ogg")

function status_init(status)
    local owner = status:owner()
    local sprite = owner:sprite()
    local color = Color.new(0, 0, 0, 255)

    local shadow_rule = IntangibleRule.new()

    shadow_rule.duration = status:remaining_time()

    local original_color = owner:sprite():color()
    local component = owner:create_component(Lifetime.Scene)

    Resources.play_audio(start_sound)

    -- Require Sword element to pierce.
    shadow_rule.element_weaknesses = { Element.Sword }

    shadow_rule.hit_weaknesses = { Hit.Drain }

    component.on_update_func = function()
        sprite:set_color(color)
        sprite:set_color_mode(ColorMode.Multiply)
    end

    -- Return the sprite to the original color.
    status.on_delete_func = function(self)
        Resources.play_audio(end_sound)
        sprite:set_color(original_color)
        component:eject()
    end

    -- Set intangible.
    owner:set_intangible(true, shadow_rule)
end
