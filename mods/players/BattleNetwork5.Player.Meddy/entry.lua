function player_init(player)
    player:set_height(52.0)

    local base_texture = Resources.load_texture("battle.png")
    local base_animation_path = "battle.animation"

    player:load_animation(base_animation_path)
    player:set_texture(base_texture)

    player:set_charge_position(0, -20)


    player.normal_attack_func = function()
        return Buster.new(player, false, player:attack_level())
    end

    player.charged_attack_func = function()
        return Buster.new(player, true, player:attack_level() * 10)
    end

    local pill_component = player:create_component(Lifetime.CardSelectOpen)

    local pill_list = {
        { range = 4,  wound_range = 3,  id = "BattleNetwork5.Medicine.Yellow" },
        { range = 8,  wound_range = 6,  id = "BattleNetwork5.Medicine.Black" },
        { range = 13, wound_range = 9,  id = "BattleNetwork6.Class01.Standard.192" },
        { range = 14, wound_range = 10, id = "BattleNetwork5.Medicine.Purple" },
        { range = 16, wound_range = 16, id = "BattleNetwork5.Medicine.Pink" }
    }

    local function get_random_pill(is_wounded)
        local number = math.random(1, 16)
        local pill;
        local range;
        for index, value in ipairs(pill_list) do
            if is_wounded then range = value.wound_range else range = value.range end
            if number <= range then
                pill = value.id
                break
            end
        end
        return pill
    end

    pill_component.on_update_func = function(self)
        local is_wounded = false
        if player:health() <= math.floor(player:max_health() / 2) then is_wounded = true end

        for i = 1, 2 do
            player:set_fixed_card(CardProperties.from_package(get_random_pill(is_wounded), "*"), i)
        end
    end

    -- Example of a form that makes the player very tall.
    -- local tall_meddy = player:create_form()

    -- tall_meddy.on_activate_func = function(self, player)
    --     player:sprite():set_height(130)
    -- end

    -- tall_meddy.on_deactivate_func = function(self, player)
    --     player:sprite():set_height(52)
    -- end
end
