local bomb = require('bomb/bomb.lua')

bomb.name="Whirlpool"
bomb.damage=0
bomb.element=Element.None
bomb.description = "Whirlpool offs weak enemies!"
bomb.codes = {"A","C","E","G","I"}

function package_init(package)
    local props = package:get_card_props()
    --standard properties
    props.short_name = bomb.name
    props.damage = bomb.damage
    props.time_freeze = false
    props.element = bomb.element
    props.description = bomb.description

    package:declare_package_id("com.Dawn.Card.Whirpool")
    package:set_icon_texture_path("icon.png")
    package:set_preview_texture_path("preview.png")
    package:set_codes(bomb.codes)
end

card_init = bomb.card_init