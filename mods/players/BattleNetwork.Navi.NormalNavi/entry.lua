---@type BattleNetwork.Emotions
local EmotionsLib = require("BattleNetwork.Emotions")

function player_init(player)
    player:set_height(40)
    player:load_animation("battle.animation")
    player:set_texture("battle.png")
    player:set_emotions_texture(Resources.load_texture("emotions.png"))
    player:load_emotions_animation("emotions.animation")
    player:set_emotion("DEFAULT")

    --- emotions
    EmotionsLib.implement_supported_full(player)

    local MINI_TEXTURE = Resources.load_texture("mini.png")
    local rng = 0
    local special = true

    local function create_projectile(player, tile)
        local spell = Spell.new(player:team())
        spell:set_facing(player:facing())
        spell:set_hit_props(HitProps.new(math.ceil(player:attack_level() * 1.5), Hit.NoCounter, Element.None, player:context()))
        spell:set_texture(MINI_TEXTURE)

        -- Use layering to draw on top of enemies
        local sprite = spell:sprite()
        sprite:set_layer(-1)

        -- obtain and set up the animatino so it knows how to draw
        -- instead of just using the entire sprite sheet
        local animation = spell:animation()
        animation:load("mini.animation")
        animation:set_state("DEFAULT")

        local origin = player:sprite():origin()
        local fire_x = origin.x * 0.5
        local fire_y = -player:height() * 0.6

        spell:set_offset(fire_x, fire_y)

        local slide = 9 - math.min(5, player:rapid_level())

        -- Determine if we hit anything
        spell.on_update_func = function(self)
            -- deal damage.
            spell:attack_tile()

            -- If the tile is an edge and we're moving, say goodbye
            if spell:current_tile():is_edge() and self._slide_started then
            self:delete()
            end

            -- Obtain the destination tile.
            local dest = self:get_tile(spell:facing(), 1)

            -- Only slide if we haven't hit anything yet
            --Slide to the next tile at 5 frames per tile. It's meant to be fast.
            self:slide(dest, slide, function() self.slide_started = true end)
        end

        spell.on_collision_func = function(self, other)
            spell:delete()
        end

        -- Just return true so that no panel blocks it. Let it hit an enemy.
        spell.can_move_to_func = function(tile) return true end

        Field.spawn(spell, tile)
    end

    --Passives
    -- Null Chips deal 25% more damage
    local stab_aux_prop = AuxProp.new()
        :require_card_element(Element.None)
        :increase_card_multiplier(0.25)
	player:add_aux_prop(stab_aux_prop)

    -- 20% chance to shoot a small blast with your buster shot for 1.5x attack. Speed scales with speed
    player.normal_attack_func = function()
        rng = math.random(1,4)
        if rng == 4 then
            create_projectile(player, player:current_tile())
        end
        return Buster.new(player, false, player:attack_level())
    end

    player.charged_attack_func = function()
        local card_props = CardProperties.from_package("LDR100.card.plyr.23.NormCann")
        card_props.damage = 25 + math.min(5, player:attack_level()) * 25

        return Action.from_card(player, card_props)
    end

    -- Special Once per turn summon a random support
    player:create_component(Lifetime.CardSelectOpen).on_update_func = function()
        special = true
    end

    player.special_attack_func = function()
        if special then
            local card_props = CardProperties.from_package("LDR100.card.plyr.24.NormSupp")
            special = false
            return Action.from_card(player, card_props)
        end
    end
end

