local bn_assets = require("BattleNetwork.Assets")
local create_version_selector = require("./version_selector")

---@type PanelStepLib
local PanelStepLib = require("dev.konstinople.library.panel_step")

local GutsBuster = require("BattleNetwork4.Action.GutsMachGun")

local panel_step = PanelStepLib.new_panel_step()

---@type ShieldLib
local ShieldLib = require("dev.konstinople.library.shield")

local shield_impact_sfx = bn_assets.load_audio("guard.ogg")
local shield = ShieldLib.new_shield()
shield:set_execute_sfx(bn_assets.load_audio("shield&reflect.ogg"))
shield:set_shield_texture(bn_assets.load_texture("shield.png"))
shield:set_shield_animation_path(bn_assets.fetch_animation_path("shield.animation"))
shield:set_shield_animation_state("REFLECT_RED")
shield:set_impact_texture(bn_assets.load_texture("shield_impact.png"))
shield:set_impact_animation_path(bn_assets.fetch_animation_path("shield_impact.animation"))
shield:set_duration(63)

local shield_reflect = ShieldLib.new_reflect()
shield_reflect:set_attack_texture(bn_assets.load_texture("buster_charged_impact.png"))
shield_reflect:set_attack_animation_path(bn_assets.fetch_animation_path("buster_charged_impact.animation"))

---@type BombLib
local BombLib = require("dev.konstinople.library.bomb")

local bomb = BombLib.new_bomb()
local dice_bomb_texture = Resources.load_texture("forms/BM_02_NUMBER/dice_bomb.png")
bomb:set_bomb_texture(dice_bomb_texture)
bomb:set_bomb_animation_path(_folder_path .. "forms/BM_02_NUMBER/dice_bomb.animation")
bomb:set_bomb_held_animation_state("HIDDEN")
bomb:set_bomb_animation_state("SPIN")
bomb:set_bomb_shadow(Shadow.Small)
bomb:set_execute_sfx(bn_assets.load_audio("lob_bomb.ogg"))

local button_texture = Resources.load_texture("button.png")
local button_anim_path = "button.animation"
local button_preview_texture = Resources.load_texture("soul_unison_preview.png")

local form_emotions_texture;
local staged_soul_aqua = Resources.load_texture("SOUL_ICON_AQUA.png")
local staged_soul_wood = Resources.load_texture("SOUL_ICON_WOOD.png")
local staged_soul_junk = Resources.load_texture("SOUL_ICON_JUNK.png")
local staged_soul_metal = Resources.load_texture("SOUL_ICON_METAL.png")
local staged_soul_blues = Resources.load_texture("SOUL_ICON_BLUES.png")
local staged_soul_number = Resources.load_texture("SOUL_ICON_NUMBER.png")

local staged_soul_fire = Resources.load_texture("SOUL_ICON_FIRE.png")
local staged_soul_guts = Resources.load_texture("SOUL_ICON_GUTS.png")
local staged_soul_roll = Resources.load_texture("SOUL_ICON_ROLL.png")
local staged_soul_wind = Resources.load_texture("SOUL_ICON_WIND.png")
local staged_soul_search = Resources.load_texture("SOUL_ICON_SEARCH.png")
local staged_soul_thunder = Resources.load_texture("SOUL_ICON_THUNDER.png")

local RECOVER_AUDIO = bn_assets.load_audio("recover.ogg")
local RECOVER_TEXTURE = bn_assets.load_texture("recover.png")
local RECOVER_ANIMATION = bn_assets.fetch_animation_path("recover.animation")

local bubble_impact_texture = bn_assets.load_texture("bn4_bubble_impact.png")
local bubbler_buster_texture = bn_assets.load_texture("bn4_bubbler_buster.png")
local bubble_impact_animation_path = bn_assets.fetch_animation_path("bn4_bubble_impact.animation")
local bubbler_buster_animation_path = bn_assets.fetch_animation_path("bn4_bubbler_buster.animation")

local roll_arrow_audio = bn_assets.load_audio("roll_arrow.ogg")
local roll_arrow_texture = bn_assets.load_texture("roll_arrow.png")
local roll_arrow_hit_texture = bn_assets.load_texture("roll_arrow_hit.png")
local roll_arrow_animation_path = bn_assets.fetch_animation_path("roll_arrow.animation")
local roll_arrow_hit_animation_path = bn_assets.fetch_animation_path("roll_arrow_hit.animation")

local cursor_audio = bn_assets.load_audio("cursor_lockon.ogg")
local cursor_texture = bn_assets.load_texture("search_cursor.png")
local cursor_animation_path = bn_assets.fetch_animation_path("search_cursor.animation")

local search_rifle_audio = bn_assets.load_audio("gunner_shot.ogg")

local defeated_mob = bn_assets.load_audio("explosion_defeatedmob.ogg")

local land_audio = bn_assets.load_audio("physical_object_land.ogg")

local wind_puff_texture = bn_assets.load_texture("wind_puff.png")
local wind_puff_animation_path = bn_assets.fetch_animation_path("wind_puff.animation")

function player_init(player)
    local update_junk = false
    local junked_chip_list = {}
    local junk_manager_list = {}
    local wind_components = {}

    local function create_junk_managers(entity)
        local on_close_manager = entity:create_component(Lifetime.CardSelectClose)

        on_close_manager._player = entity
        on_close_manager._can_update = false
        on_close_manager.on_update_func = function(self)
            if not self._can_update then return end

            for i = 1, #self._player:staged_items(), 1 do
                local item = self._player:staged_item(i)

                if item.category == "icon" then goto continue end
                if item.category == "form" then goto continue end
                if item.category == "deck_discard" then goto continue end

                if item.index ~= nil then
                    local recycled_properties = self._player:deck_card_properties(item.index)

                    table.insert(junked_chip_list,
                        {
                            card_properties = recycled_properties,
                            used = false
                        }
                    )
                end

                ::continue::
            end

            self._open_manager._can_update = true
        end

        on_close_manager._open_manager = entity:create_component(Lifetime.CardSelectOpen)
        on_close_manager._open_manager._junk_recycle_buttons = {}
        on_close_manager._open_manager._can_update = false;
        on_close_manager._open_manager._player = entity

        on_close_manager._open_manager.on_update_func = function(self)
            if self._can_update == true then
                while #self._junk_recycle_buttons > 0 do
                    local button = table.remove(self._junk_recycle_buttons, #self._junk_recycle_buttons)
                    if button and button:deleted() == false then button:delete() end
                end

                local shuffled = {}

                for i = 1, #junked_chip_list, 1 do
                    local pos = math.random(1, #shuffled + 1)
                    if junked_chip_list[i].used == false then
                        table.insert(shuffled, pos, { junked = junked_chip_list[i], list_index = i })
                    end
                end

                local recycle_index = 1;
                local recycle_count = 1;

                while (recycle_index <= #shuffled and recycle_count <= 2) do
                    local random_chip = shuffled[recycle_index]
                    local junked = random_chip.junked
                    local original_index = random_chip.list_index

                    if junked ~= nil and junked.used == false then
                        local recycle_props = junked.card_properties

                        self._player:set_fixed_card(recycle_props, recycle_count)

                        junked_chip_list[original_index].used = true

                        recycle_count = recycle_count + 1
                    end

                    recycle_index = recycle_index + 1
                end

                self._can_update = false
            end
        end

        table.insert(junk_manager_list, on_close_manager)
    end

    local wind_spawned = false;

    local function create_wind_gust(tile)
        local gust = Spell.new(player:team())

        local hit_props = HitProps.new(
            0,
            Hit.None,
            Element.None,
            player:context(),
            Drag.None
        )

        gust:set_hit_props(
            hit_props
        )

        local field = player:field()

        local facing = tile:facing()
        gust:set_facing(facing)

        gust:set_texture(wind_puff_texture)

        local gust_anim = gust:animation()
        gust_anim:load(wind_puff_animation_path)

        gust_anim:set_state("GREEN")
        gust_anim:set_playback(Playback.Loop)

        gust.on_update_func = function(self)
            if player:is_team(self:current_tile():team()) then
                self:delete()
                return
            end

            self:attack_tile()

            self:slide(self:current_tile():get_tile(self:facing(), 1), 2)
        end

        gust.on_delete_func = function(self)
            wind_spawned = false;
            self:erase()
        end

        gust.on_collision_func = function(self, other)
            print("collision")
            if wind_components[other:id()] ~= nil then return end

            local slide_component = other:create_component(Lifetime.ActiveBattle)

            slide_component._direction = self:facing()

            slide_component.on_update_func = function(self)
                local owner = self:owner()

                local slide_tile = owner:get_tile(self._direction, 1)

                if not owner:can_move_to(slide_tile) then
                    wind_components[other:id()] = nil
                    self:eject()
                    return
                end

                if owner:is_moving() then return end
                if owner:is_dragged() then return end
                owner:slide(slide_tile, 6)
            end

            wind_components[other:id()] = slide_component
        end

        field:spawn(gust, tile)
    end

    local function create_cursor()
        local cursor = Spell.new(player:team())

        cursor:set_texture(cursor_texture)

        local anim = cursor:animation()
        anim:load(cursor_animation_path)

        cursor:sprite():set_layer(-5)

        cursor:set_offset(0, -10)

        anim:set_state("SPAWN")

        anim:apply(cursor:sprite())

        -- Play the sound.
        Resources.play_audio(cursor_audio)

        anim:on_complete(function()
            -- Change animation state.
            cursor:animation():set_state("LOCK")
        end)

        return cursor
    end

    local function create_aqua_soul_charge_shot(user, props)
        local spell = Spell.new(user:team())
        local direction = user:facing()
        local field = user:field()

        spell:set_facing(direction)

        spell:set_hit_props(props)

        spell._slide_started = false
        spell._should_erase = false

        spell.on_update_func = function(self)
            local tile = spell:current_tile()
            if self._should_erase == true then
                local burst_tiles = {
                    tile,
                    tile:get_tile(direction, 1),
                }

                for i = 1, #burst_tiles, 1 do
                    local fx = Artifact.new()
                    fx:set_texture(bubble_impact_texture)

                    local fx_anim = fx:animation()
                    fx_anim:load(bubble_impact_animation_path)
                    fx_anim:set_state("FAST")
                    fx_anim:on_complete(function()
                        fx:erase()
                    end)

                    local spawn_tile = burst_tiles[i]
                    if spawn_tile and not spawn_tile:is_edge() then
                        field:spawn(fx, spawn_tile)
                        spawn_tile:attack_entities(self)
                    end
                end

                self:delete()

                return
            end

            tile:attack_entities(self)

            if self:is_sliding() == false then
                if tile:is_edge() and self._slide_started then
                    self:delete()
                end

                local dest = self:get_tile(direction, 1)
                local ref = self
                self:slide(dest, 2, function() ref._slide_started = true end)
            end
        end

        spell.on_collision_func = function(self, other)
            self._should_erase = true;
        end

        spell.on_delete_func = function(self)
            self:erase()
        end

        spell.can_move_to_func = function(tile)
            return true
        end

        -- Resources.play_audio(AUDIO)
        return spell
    end

    local function match_element(card_properties, elements, is_secondary_allowed)
        local result = false
        -- Obey element restrictions.
        -- Secondary element restriction can be toggled by passing in false as the third argument..
        for _, element in ipairs(elements) do
            if card_properties.element == element then result = true end
            if is_secondary_allowed and card_properties.secondary_element == element then result = true end
        end

        -- Doesn't match restrictions.
        return result
    end

    local function create_recov()
        local artifact = Artifact.new()
        artifact:set_texture(RECOVER_TEXTURE)
        artifact:set_facing(player:facing())
        artifact:sprite():set_layer(-1)

        local anim = artifact:animation()
        anim:load(RECOVER_ANIMATION)
        anim:set_state("DEFAULT")
        anim:on_complete(function()
            artifact:erase()
        end)

        artifact.on_spawn_func = function()
            Resources.play_audio(RECOVER_AUDIO)
        end

        if player:spawned() then
            player:field():spawn(artifact, player:current_tile())
        end
    end

    local function create_form_prop(required_element, is_exclusive, minimum_damage, damage_bonus, hit_flag,
                                    is_duration, duration_or_level)
        local prop = AuxProp.new()
        local element_list = {
            Element.None,
            Element.Fire,
            Element.Aqua,
            Element.Elec,
            Element.Wood,
            Element.Sword,
            Element.Wind,
            Element.Cursor,
            Element.Summon,
            Element.Plus,
            Element.Break
        }

        if required_element ~= nil then
            for _, value in ipairs(element_list) do
                if required_element == value then
                    prop:require_card_element(value)
                elseif required_element ~= value and is_exclusive == true then
                    prop:require_card_not_element(value)
                end
            end
        end

        if minimum_damage ~= nil then
            prop:require_card_damage(Compare.GE, minimum_damage)
        end

        if damage_bonus ~= nil then
            prop:increase_card_damage(damage_bonus)
        end

        if hit_flag ~= nil then
            prop:update_context(function(context)
                context.flags = context.flags & ~Hit.mutual_exclusions_for(hit_flag) | hit_flag

                if is_duration == true then
                    context.status_durations[hit_flag] = duration_or_level
                else
                    context.status_durations[hit_flag] = Hit.duration_for(hit_flag, duration_or_level)
                end

                return context
            end)
        end

        return prop
    end

    local function choose_souls(souls, button)
        button:animation():set_state("INACTIVE")
        return souls
    end

    player:set_height(38.0)

    local base_texture = Resources.load_texture("battle.png")
    local base_animation_path = "battle.animation"

    local overlay;
    local add_gaia;
    local form_path;
    local junk_paradox;
    local chosen_souls;
    local overlay_texture;
    local form_card_index;
    local soul_turn_tracker;
    local overlay_animation;
    local pre_unison_emotion;
    local pre_unison_element;
    local unison_end_component;

    local wind_list = {};
    local guts_timer = 0;
    local mash_count = 0;
    local wind_timer = 0;
    local soul_turns = 0;
    local wind_shoes = {};
    local wind_list_index = 1;
    local active_aux_props = {}
    local status_guard_list = Hit.Freeze | Hit.Paralyze | Hit.Blind | Hit.Confuse

    -- Blue Moon soul abilities
    local mult_up = AuxProp.new()
        :require_charged_card()
        :increase_card_multiplier(1)

    local damage_plus_ten = create_form_prop(Element.None, true, 1, 10)

    local break_buster = AuxProp.new()
        :require_action(ActionType.Normal)
        :update_context(function(context)
            context.flags = context.flags & ~Hit.mutual_exclusions_for(Hit.PierceGuard) | Hit.PierceGuard
            return context
        end)

    local charged_cards_pierce_guards = AuxProp.new()
        :require_charged_card()
        :update_context(function(context)
            context.flags = context.flags & ~Hit.mutual_exclusions_for(Hit.PierceGuard) | Hit.PierceGuard
            return context
        end)

    local status_guard = AuxProp.new()
        :declare_immunity(status_guard_list)

    local swords_cannot_flash = AuxProp.new()
        :require_card_hit_flags(Hit.Flash)
        :require_card_element(Element.Sword)
        :update_context(function(context)
            context.flags = context.flags & ~Hit.Flash
            context.status_durations[Hit.Flash] = 0
            return context
        end)

    local on_close_manager = player:create_component(Lifetime.CardSelectClose)

    on_close_manager.on_update_func = function(self)
        if soul_turns > 0 then player:set_emotion("DEFAULT_" .. tostring(soul_turns)) end

        if add_gaia ~= nil then
            add_gaia._can_update = true
        end

        if update_junk == true then
            update_junk = false

            for _, manager in ipairs(junk_manager_list) do
                manager._can_update = true
            end
        end
    end

    -- Red Sun soul abilities
    local self_heal = AuxProp.new()
        :require_action(ActionType.Card)
        :intercept_action(function(action)
            player:set_health(player:health() + math.floor(player:max_health() * 0.1))
            return action
        end)
        :with_callback(create_recov)

    local damage_plus_thirty = create_form_prop(Element.None, true, 1, 30, nil, nil, nil)

    local wind_plus_ten = create_form_prop(Element.Wind, true, 1, 10)

    local add_paralysis_null = AuxProp.new()
        :require_card_time_freeze(false)
        :require_card_element(Element.None)
        :require_card_hit_flags_absent(Hit.Paralyze)
        :update_context(function(context)
            context.flags = context.flags & ~Hit.mutual_exclusions_for(Hit.Paralyze) | Hit.Paralyze
            context.status_durations[Hit.Paralyze] = 90
            return context
        end)

    local add_paralysis_elec = AuxProp.new()
        :require_card_time_freeze(false)
        :require_card_element(Element.Elec)
        :require_card_hit_flags_absent(Hit.Paralyze)
        :update_context(function(context)
            context.flags = context.flags & ~Hit.mutual_exclusions_for(Hit.Paralyze) | Hit.Paralyze
            context.status_durations[Hit.Paralyze] = 90
            return context
        end)

    player:load_animation(base_animation_path)
    player:set_texture(base_texture)
    player:set_charge_position(0, -20)

    local soul_aqua = player:create_hidden_form()
    local soul_number = player:create_hidden_form()
    local soul_metal = player:create_hidden_form()
    local soul_wood = player:create_hidden_form()
    local soul_junk = player:create_hidden_form()
    local soul_blues = player:create_hidden_form()

    local blue_moon_souls = {
        {
            soul = soul_aqua,
            element = Element.Aqua,
            icon = staged_soul_aqua,
            path = "forms/BM_01_AQUA/",
            used = false
        },
        {
            soul = soul_number,
            element = Element.Plus,
            icon = staged_soul_number,
            path = "forms/BM_02_NUMBER/",
            used = false
        },
        {
            soul = soul_metal,
            element = Element.Break,
            icon = staged_soul_metal,
            path = "forms/BM_03_METAL/",
            used = false
        },
        {
            soul = soul_wood,
            element = Element.Wood,
            icon = staged_soul_wood,
            path = "forms/BM_04_WOOD/",
            used = false
        },
        {
            soul = soul_junk,
            element = Element.Summon,
            icon = staged_soul_junk,
            path = "forms/BM_05_JUNK/",
            used = false
        },
        {
            soul = soul_blues,
            element = Element.Sword,
            icon = staged_soul_blues,
            path = "forms/BM_06_BLUES/",
            used = false
        }
    }

    local soul_fire = player:create_hidden_form()
    local soul_guts = player:create_hidden_form()
    local soul_roll = player:create_hidden_form()
    local soul_wind = player:create_hidden_form()
    local soul_thunder = player:create_hidden_form()
    local soul_search = player:create_hidden_form()

    local red_sun_souls = {
        {
            soul = soul_fire,
            element = Element.Fire,
            icon = staged_soul_fire,
            path = "forms/RS_01_FIRE/",
            used = false
        },
        {
            soul = soul_guts,
            element = Element.None,
            hit_flag = Hit.PierceGround,
            icon = staged_soul_guts,
            path = "forms/RS_02_GUTS/",
            used = false
        },
        {
            soul = soul_roll,
            element = Element.None,
            icon = staged_soul_roll,
            path = "forms/RS_03_ROLL/",
            recover = true,
            used = false
        },
        {
            soul = soul_wind,
            element = Element.Wind,
            icon = staged_soul_wind,
            path = "forms/RS_04_WIND/",
            used = false
        },
        {
            soul = soul_thunder,
            element = Element.Elec,
            icon = staged_soul_thunder,
            path = "forms/RS_05_THUNDER/",
            used = false
        },
        {
            soul = soul_search,
            element = Element.Cursor,
            icon = staged_soul_search,
            path = "forms/RS_06_SEARCH/",
            used = false
        }
    }

    -- shield
    local shield_cooldown = 0

    local base_emotion_texture = Resources.load_texture("emotions.png");
    local base_emotion_animation_path = "emotions.animation";

    player:set_emotions_texture(base_emotion_texture)
    player:load_emotions_animation(base_emotion_animation_path)
    player:set_emotion("DEFAULT")

    local active_form = nil;
    local readied_form = nil;
    local unison_button = player:create_special_button()
    local should_end_form = false;

    unison_button:set_texture(button_texture)
    unison_button:set_preview_texture(button_preview_texture)

    local unison_button_animation = unison_button:animation()
    unison_button_animation:load(button_anim_path)

    local soul_choice_component;
    local turn_level_boost = 0
    local is_soul_staged = false;

    local function change_visuals(texture, animation, already_loaded, path)
        if path ~= nil then
            texture = path .. texture
            animation = path .. animation
        end

        if already_loaded ~= true then
            texture = Resources.load_texture(texture)
        end

        player:set_texture(texture)
        player:load_animation(animation)
    end

    local function handle_soul_emotion(state)
        pre_unison_emotion = player:emotion()

        player:set_emotion(state)
    end

    local function handle_aux_prop_removal()
        while #active_aux_props > 0 do
            local aux_prop = table.remove(active_aux_props, #active_aux_props)
            player:remove_aux_prop(aux_prop)
        end
    end

    local function handle_form_deactivation(form)
        change_visuals(base_texture, base_animation_path, true)

        player:set_emotions_texture(base_emotion_texture)
        player:load_emotions_animation(base_emotion_animation_path)
        player:set_element(pre_unison_element)
        player:set_emotion(pre_unison_emotion)

        handle_aux_prop_removal()

        form:deactivate()

        active_form = nil
    end

    local handle_overlay_erasure = function()
        if overlay == nil then return end

        overlay:hide()
        player:sprite():remove_node(overlay)
        overlay = nil
        overlay_texture = nil
        overlay_animation = nil
    end

    local common_deselect_func = function()
        player:set_emotion(pre_unison_emotion)
        is_soul_staged = false
    end

    local function create_or_update_soul_turn_tracker()
        -- Delete the tracker if it exists. We may have changed forms while another was still active.
        if soul_turn_tracker ~= nil then soul_turn_tracker:eject() end

        soul_turn_tracker = player:create_component(Lifetime.CardSelectOpen)

        soul_turns = math.min(9, 3 + turn_level_boost)

        player:set_emotion("DEFAULT_" .. tostring(soul_turns))

        soul_turn_tracker.on_update_func = function(tracker)
            soul_turns = soul_turns - 1

            player:set_emotion("DEFAULT_" .. tostring(soul_turns))

            if soul_turns <= 0 then
                should_end_form = true
                tracker:eject()
            end
        end

        unison_end_component = player:create_component(Lifetime.Battle)

        unison_end_component.on_update_func = function(self)
            if should_end_form ~= true then return end
            should_end_form = false
            handle_form_deactivation(active_form)
        end
    end

    local function handle_form_activation(form, element, aux_props)
        handle_aux_prop_removal()

        is_soul_staged = false
        active_form = form

        player:set_element(element)

        change_visuals("battle.png", "battle.animation", false, form_path)

        form_emotions_texture = Resources.load_texture(form_path .. "emotions.png")

        player:set_emotions_texture(form_emotions_texture)
        player:load_emotions_animation("forms/emotions.animation")

        while #aux_props > 0 do
            local aux_prop = table.remove(aux_props, #aux_props)
            table.insert(active_aux_props, aux_prop)
            player:add_aux_prop(aux_prop)
        end

        for _, value in ipairs(chosen_souls) do
            if value.soul == form then
                value.used = true
            end
        end

        create_or_update_soul_turn_tracker()
    end

    local function handle_staging_form()
        if readied_form == nil then return end

        form_path = readied_form.path

        local items = player:staged_items()
        local count = #items

        is_soul_staged = true

        form_card_index = player:staged_item(count).index

        player:stage_deck_discard(form_card_index, function()
            player:pop_staged_item()
        end)

        player:stage_form(readied_form.soul, readied_form.icon, function()
            form_path = nil
            is_soul_staged = false
        end)
    end

    local function match_emotion()
        local emotion = player:emotion()
        if emotion == "WORRIED" then return false end
        if string.find(emotion, "SOUL_") then return false end
        if emotion == "EVIL" then return false end
        return true
    end

    player.on_spawn_func = function()
        player:boost_augment("BattleNetwork4.DarkChipSlots", 1)

        local add_junk_managers = player:create_component(Lifetime.Scene)
        add_junk_managers._timer = 240
        add_junk_managers.on_update_func = function(self)
            self._timer = self._timer - 1
            if self._timer > 0 and #player:staged_items() == 0 then return end

            local field = player:field()

            local player_list = field:find_players(function(p)
                if not p then return false end
                if p:deleted() or p:will_erase_eof() then return false end
                if not p:spawned() then return false end
                return true
            end)

            for _, entity in ipairs(player_list) do
                create_junk_managers(entity)
            end

            self:eject()
        end

        local boost_augment = player:get_augment("BattleNetwork5.NaviCustomizer.Program35.SoulTime1")
        if boost_augment ~= nil then turn_level_boost = boost_augment:level() end

        pre_unison_element = player:element()

        soul_choice_component = player:create_component(Lifetime.Scene)
        soul_choice_component.on_update_func = function(self)
            if player:staged_items_confirmed() == true then return end
            if chosen_souls ~= nil then
                self:eject()
                return
            end

            if player:input_has(Input.Pressed.Special) then
                if unison_button_animation:state() == "SELECT_RS" then
                    unison_button_animation:set_state("SELECT_BM")
                else
                    unison_button_animation:set_state("SELECT_RS")
                end
            end
        end
    end

    player.on_update_func = function() end

    -- Select Functions
    soul_aqua.on_select_func = function(self)
        handle_soul_emotion("SOUL_AQUA")
    end

    soul_number.on_select_func = function(self)
        handle_soul_emotion("SOUL_NUMBER")
    end

    soul_metal.on_select_func = function(self)
        handle_soul_emotion("SOUL_METAL")
    end

    soul_wood.on_select_func = function(self)
        handle_soul_emotion("SOUL_WOOD")
    end

    soul_junk.on_select_func = function(self)
        handle_soul_emotion("SOUL_JUNK")
        update_junk = true
    end

    soul_blues.on_select_func = function(self)
        handle_soul_emotion("SOUL_BLUES")
    end

    soul_fire.on_select_func = function(self)
        handle_soul_emotion("SOUL_FIRE")
    end

    soul_guts.on_select_func = function(self)
        handle_soul_emotion("SOUL_GUTS")
    end

    soul_roll.on_select_func = function(self)
        handle_soul_emotion("SOUL_ROLL")
    end

    soul_wind.on_select_func = function(self)
        handle_soul_emotion("SOUL_WIND")
    end

    soul_thunder.on_select_func = function(self)
        handle_soul_emotion("SOUL_THUNDER")
    end

    soul_search.on_select_func = function(self)
        handle_soul_emotion("SOUL_SEARCH")
    end

    -- Deselect Functions
    soul_aqua.on_deselect_func = common_deselect_func
    soul_number.on_deselect_func = common_deselect_func
    soul_metal.on_deselect_func = common_deselect_func
    soul_wood.on_deselect_func = common_deselect_func

    soul_junk.on_deselect_func = function()
        common_deselect_func()
        update_junk = false
    end

    soul_blues.on_deselect_func = common_deselect_func

    soul_fire.on_deselect_func = common_deselect_func
    soul_guts.on_deselect_func = common_deselect_func
    soul_roll.on_deselect_func = common_deselect_func
    soul_wind.on_deselect_func = common_deselect_func
    soul_thunder.on_deselect_func = common_deselect_func
    soul_search.on_deselect_func = common_deselect_func

    -- Activation Functions
    soul_aqua.on_activate_func = function(self)
        handle_form_activation(self, Element.Aqua, { mult_up })
    end

    soul_number.on_activate_func = function(self)
        handle_form_activation(self, Element.None, { damage_plus_ten })
        player:boost_hand_size(10)

        overlay = player:create_node()
        overlay_texture = Resources.load_texture("forms/BM_02_NUMBER/idle_overlay.png")

        overlay:set_texture(overlay_texture)

        overlay:use_root_shader(true)

        overlay_animation = Animation.new("forms/BM_02_NUMBER/idle_overlay.animation")
        overlay_animation:set_state("DEFAULT")
        overlay_animation:set_playback(Playback.Loop)
        overlay_animation:apply(overlay)
    end

    soul_metal.on_activate_func = function(self)
        handle_form_activation(self, Element.None, { break_buster, mult_up, charged_cards_pierce_guards })
    end

    soul_wood.on_activate_func = function(self)
        add_gaia = player:create_component(Lifetime.Battle)
        add_gaia._can_update = true

        add_gaia.on_update_func = function(self)
            if self._can_update == false then return end
            local card_list = player:field_cards()
            if #card_list < 2 then return end

            for i = 1, #card_list, 1 do
                local card = player:field_card(i)
                if card == nil then return end
                if card.element ~= Element.Wood or card.can_boost ~= true or card.time_freeze == true then return end

                local next_card = player:field_card(i + 1)
                if next_card == nil then return end
                if next_card.element ~= Element.None then return end
                if next_card.secondary_element ~= Element.None then return end
                if next_card.damage < 1 then return end
                if next_card.card_class ~= CardClass.Standard then return end

                card.damage = card.damage + next_card.damage
                player:set_field_card(i, card)
                player:remove_field_card(i + 1)
            end

            self._can_update = false
        end

        handle_form_activation(self, Element.Wood, { status_guard })
    end

    soul_junk.on_activate_func = function(self)
        handle_form_activation(self, Element.None, {})

        local enemy_list = player:field():find_characters(function(character)
            return character and character:hittable() and not player:is_team(character:team())
        end)

        for _, enemy in ipairs(enemy_list) do
            junk_paradox = AuxProp.new()
                :require_health(Compare.GE, 1)
                :apply_status(Hit.Confuse, Hit.duration_for(Hit.Confuse, 1))
                :once()

            enemy:add_aux_prop(junk_paradox)
        end
    end

    soul_blues.on_activate_func = function(self)
        handle_form_activation(self, Element.None, { mult_up, swords_cannot_flash })
    end

    soul_fire.on_activate_func = function(self)
        handle_form_activation(self, Element.Fire, {})

        local field = player:field()
        for x = 1, 6, 1 do
            field:tile_at(x, 2):set_state(TileState.Grass)
            if x == 2 or x == 5 then
                field:tile_at(x, 1):set_state(TileState.Grass)
                field:tile_at(x, 3):set_state(TileState.Grass)
            end
        end

        field:shake(12, 40)

        overlay = player:create_node()

        overlay_texture = Resources.load_texture("forms/RS_01_FIRE/idle_overlay.png")
        overlay:set_texture(overlay_texture)

        overlay:use_root_shader(true)

        overlay_animation = Animation.new("forms/RS_01_FIRE/idle_overlay.animation")
        overlay_animation:set_state(player:animation():state())
        overlay_animation:set_playback(Playback.Loop)
        overlay_animation:apply(overlay)
    end

    soul_guts.on_activate_func = function(self)
        handle_form_activation(self, Element.None, { damage_plus_thirty })

        overlay = player:create_node()
        overlay:hide()

        overlay_texture = Resources.load_texture("forms/RS_02_GUTS/guts_punch.png")
        overlay:set_texture(overlay_texture)

        overlay:use_root_shader(true)

        overlay_animation = Animation.new("forms/RS_02_GUTS/guts_punch.animation")
        overlay_animation:set_state(player:animation():state())
        overlay_animation:apply(overlay)

        player:field():shake(12, 40)
    end

    soul_roll.on_activate_func = function(self)
        handle_form_activation(self, Element.None, { self_heal })
    end

    soul_wind.on_activate_func = function(self)
        handle_form_activation(self, Element.Wind, { wind_plus_ten })

        local card_properties = CardProperties.from_package("BattleNetwork4.Class01.Standard.130")
        card_properties.prevent_time_freeze_counter = true
        card_properties.skip_time_freeze_intro = true

        player:queue_action(Action.from_card(player, card_properties))

        local field = player:field()
        local wind_x = field:width() - 1
        for y = 1, 3, 1 do
            table.insert(wind_list, field:tile_at(wind_x, y))
        end

        if player:ignoring_negative_tile_effects() == false then
            player:ignore_negative_tile_effects(true)
            table.insert(wind_shoes, "NEGATIVE_EFFECTS")
        end

        if player:ignoring_hole_tiles() == false then
            player:ignore_hole_tiles(true)
            table.insert(wind_shoes, "HOLES")
        end
    end

    soul_thunder.on_activate_func = function(self)
        handle_form_activation(self, Element.Elec, { add_paralysis_null, add_paralysis_elec })
    end

    soul_search.on_activate_func = function(self)
        handle_form_activation(self, Element.None, {})

        local list = player:field():find_entities(function(ent)
            if ent:will_erase_eof() then return false end
            if ent:deleted() then return false end
            if not ent:spawned() then return false end
            if Living.from(ent) == nil then return false end
            return ent:intangible()
        end)

        for _, entity in ipairs(list) do
            entity:set_intangible(false)
        end

        player:boost_augment("dev.GladeWoodsgrove.ModularShuffle", 3)
    end

    -- Deactivation Functions
    soul_aqua.on_deactivate_func = function(self) end

    soul_number.on_deactivate_func = function(self)
        handle_overlay_erasure()
    end

    soul_metal.on_deactivate_func = function(self) end

    soul_wood.on_deactivate_func = function(self)
        if add_gaia ~= nil then add_gaia:eject() end
    end

    soul_junk.on_deactivate_func = function(self)
        for _, manager in ipairs(junk_manager_list) do
            manager._open_manager:eject()
            manager:eject()
        end
    end

    soul_blues.on_deactivate_func = function(self) end

    soul_fire.on_deactivate_func = function(self)
        handle_overlay_erasure()
    end

    soul_guts.on_deactivate_func = function(self)
        handle_overlay_erasure()
    end

    soul_roll.on_deactivate_func = function(self) end
    soul_wind.on_deactivate_func = function(self)
        for _, value in ipairs(wind_shoes) do
            if value == "HOLES" then player:ignore_hole_tiles(false) end
            if value == "NEGATIVE_EFFECTS" then player:ignore_negative_tile_effects(false) end
        end
    end
    soul_thunder.on_deactivate_func = function(self) end

    soul_search.on_deactivate_func = function(self)
        player:boost_augment("dev.GladeWoodsgrove.ModularShuffle", -3)
    end

    -- Card Charge Functions
    local no_card_charge_func = function()
        return nil
    end

    local no_charged_card_activation = function()
        return nil
    end

    soul_aqua.calculate_card_charge_time_func = function(self, card_properties)
        if card_properties.time_freeze == true then return nil end
        if not match_element(card_properties, { Element.Aqua }, true) then return nil end
        return 30
    end

    soul_aqua.charged_card_func = function(self, card_properties)
        return Action.from_card(player, card_properties)
    end

    soul_number.calculate_card_charge_time_func = no_card_charge_func
    soul_number.charged_card_func = no_charged_card_activation

    soul_metal.calculate_card_charge_time_func = function(self, card_properties)
        if card_properties.time_freeze == true then return nil end
        if not match_element(card_properties, { Element.Break }, true) then return nil end
        return 60
    end

    soul_metal.charged_card_func = function(self, card_properties)
        return Action.from_card(player, card_properties)
    end

    soul_wood.calculate_card_charge_time_func = no_card_charge_func
    soul_wood.charged_card_func = no_charged_card_activation

    soul_blues.calculate_card_charge_time_func = function(self, card_properties)
        if card_properties.time_freeze == true then return nil end
        if not match_element(card_properties, { Element.Sword }, false) then return nil end
        return 40
    end

    soul_blues.charged_card_func = function(self, card)
        card.damage = card.damage * 2
        local action = Action.from_card(player, card)

        if action then
            return panel_step:wrap_action(action)
        end
    end

    soul_fire.calculate_card_charge_time_func = function(self, card_properties)
        if not match_element(card_properties, { Element.Fire }, false) then return nil end
        return 70
    end

    soul_fire.charged_card_func = function(self, card)
        local card_properties = CardProperties.from_package("BattleNetwork4.HiddenAbility.FireArm")
        card_properties.hit_flags = card_properties.hit_flags & Hit.NoCounter
        card_properties.damage = 150

        return Action.from_card(player, card_properties)
    end

    soul_guts.calculate_card_charge_time_func = no_card_charge_func
    soul_guts.charged_card_func = no_charged_card_activation

    soul_roll.calculate_card_charge_time_func = no_card_charge_func
    soul_roll.charged_card_func = no_charged_card_activation

    soul_wind.calculate_card_charge_time_func = no_card_charge_func
    soul_wind.charged_card_func = no_charged_card_activation

    soul_thunder.calculate_card_charge_time_func = no_card_charge_func
    soul_thunder.charged_card_func = no_charged_card_activation

    soul_search.calculate_card_charge_time_func = no_card_charge_func
    soul_search.charged_card_func = no_charged_card_activation

    -- Normal Attack functions
    player.normal_attack_func = function()
        return Buster.new(player, false, player:attack_level())
    end

    soul_wind.normal_attack_func = function(self)
        local props = CardProperties.from_package("BattleNetwork6.Class01.Standard.004")

        -- Customize the damage.
        props.damage = 5

        return Action.from_card(player, props)
    end

    -- Charged Attack Functions
    player.charged_attack_func = function()
        return Buster.new(player, true, player:attack_level() * 10)
    end

    soul_aqua.charged_attack_func = function(self)
        local action = Action.new(player, "CHARACTER_SHOOT")
        action:override_animation_frames(
            {
                { 1, 2 },
                { 1, 3 },
                { 1, 2 },
                { 2, 1 },
                { 3, 2 },
                { 3, 2 },
                { 3, 2 },
                { 4, 1 }
            }
        )

        action:set_lockout(ActionLockout.new_animation())

        action.on_execute_func = function(self, user)
            local buster = self:create_attachment("BUSTER")
            buster:sprite():set_texture(bubbler_buster_texture)
            buster:sprite():set_layer(-1)

            local buster_anim = buster:animation()
            buster_anim:load(bubbler_buster_animation_path)
            buster_anim:set_state("DEFAULT")

            local hit_props = HitProps.new(
                20,
                Hit.Impact | Hit.Flinch | Hit.NoCounter,
                Element.Aqua,
                player:context(),
                Drag.None
            )

            self:add_anim_action(5, function()
                local cannonshot = create_aqua_soul_charge_shot(user, hit_props)
                local tile = user:current_tile()
                player:field():spawn(cannonshot, tile)
            end)
        end

        return action
    end

    soul_number.charged_attack_func = function(self)
        local field = player:field()
        local context = player:context()

        return bomb:create_action(player, function(tile)
            if not tile or not tile:is_walkable() then return end

            local physical_bomb = Spell.new(player:team())
            local bomb_sprite = physical_bomb:sprite()
            bomb_sprite:set_texture(dice_bomb_texture)
            bomb_sprite:set_layer(-1)

            local bomb_anim = physical_bomb:animation()
            bomb_anim:load("forms/BM_02_NUMBER/dice_bomb.animation")

            local tiles = {}
            local tile_x = tile:x()
            local tile_y = tile:y()

            for x = -1, 1, 1 do
                for y = -1, 1, 1 do
                    local prospective_tile = field:tile_at(tile_x + x, tile_y + y)
                    if prospective_tile:is_edge() then goto continue end
                    table.insert(tiles, prospective_tile)
                    ::continue::
                end
            end

            local spell = Spell.new(player:team())
            spell:set_facing(player:facing())
            spell:set_hit_props(
                HitProps.new(
                    10,
                    Hit.Impact | Hit.Flinch | Hit.Flash,
                    Element.None,
                    Element.None,
                    context,
                    Drag.None
                )
            )

            physical_bomb:set_shadow(Shadow.Small)
            physical_bomb:show_shadow()

            local spawn_explosions = false
            local bomb_flashes = false
            local flash_timer = 30
            local bomb_can_attack = false

            physical_bomb.on_spawn_func = function()
                local result = math.random(1, 6)

                physical_bomb:set_hit_props(
                    HitProps.new(
                        result * 10,
                        Hit.Impact | Hit.Flinch | Hit.Flash,
                        Element.None,
                        Element.None,
                        context,
                        Drag.None
                    )
                )

                bomb_anim:set_state("BOUNCE")

                bomb_anim:on_frame(1, function()
                    Resources.play_audio(land_audio)
                end)

                bomb_anim:set_playback(Playback.Once)
                bomb_anim:on_complete(function()
                    bomb_anim:set_state("RESULT_" .. tostring(result))
                    bomb_flashes = true
                    bomb_anim:set_playback(Playback.Loop)
                end)
            end

            physical_bomb.on_update_func = function(self)
                if bomb_flashes == true then
                    if flash_timer > 0 then
                        flash_timer = flash_timer - 1
                        return
                    end

                    bomb_can_attack = true
                    spawn_explosions = true
                    bomb_flashes = false
                    return
                end


                if bomb_can_attack ~= true then return end

                if spawn_explosions == true then
                    local i = 1;

                    while i <= #tiles do
                        local explosion = Explosion.new()
                        -- no sound
                        explosion.on_spawn_func = nil
                        field:spawn(Explosion.new(), tiles[i])
                        self:attack_tile(tiles[i])
                        i = i + 1
                    end

                    Resources.play_audio(defeated_mob)
                    spawn_explosions = false
                end

                self:erase()
            end

            spell.on_update_func = function(self)
                if #tile:find_entities(function(ent)
                        return ent:hittable()
                    end) > 0 then
                    self:attack_tile()
                else
                    field:spawn(physical_bomb, tile)
                end

                self:erase()
            end

            field:spawn(spell, tile)
        end)
    end

    soul_metal.charged_attack_func = function(self)
        local action = Action.new(player, "CHARACTER_SPECIAL")
        local field = player:field()

        action.on_execute_func = function()
            local spell = Spell.new(player:team())
            spell:set_tile_highlight(Highlight.Flash)
            local facing = player:facing()
            spell:set_hit_props(
                HitProps.new(
                    150,
                    Hit.Impact | Hit.PierceGuard | Hit.PierceGround | Hit.Drag | Hit.NoCounter,
                    Element.None,
                    Element.Break,
                    player:context(),
                    Drag.new(facing, 1)
                )
            )
            local can_spell_attack = false

            spell.on_update_func = function(self)
                if can_spell_attack == true then self:attack_tile() end
            end

            action:add_anim_action(4, function()
                can_spell_attack = true
                field:shake(4, 8)

                spell:set_tile_highlight(Highlight.Solid)
            end)

            action.on_action_end_func = function()
                spell:erase()
            end

            local tile = player:current_tile():get_tile(facing, 1)
            field:spawn(spell, tile)
        end

        return action
    end

    soul_wood.charged_attack_func = function(self)
        local card_properties = CardProperties.from_package("BattleNetwork6.Class01.Standard.053")
        card_properties.element = Element.Wood
        card_properties.damage = 20
        card_properties.hit_flags = card_properties.hit_flags & Hit.NoCounter
        return Action.from_card(player, card_properties)
    end

    soul_junk.charged_attack_func = function(self)
        local card_properties = CardProperties.from_package("BattleNetwork5.Class02.Mega.007.Poltergeist")
        card_properties.damage = 100
        card_properties.prevent_time_freeze_counter = true
        return Action.from_card(player, card_properties)
    end

    soul_blues.charged_attack_func = function(self)
        local card_properties = CardProperties.from_package("BattleNetwork6.Class01.Standard.071")
        card_properties.hit_flags = card_properties.hit_flags & Hit.NoCounter
        return Action.from_card(player, card_properties)
    end

    soul_fire.charged_attack_func = function(self)
        local card_properties = CardProperties.from_package("BattleNetwork4.HiddenAbility.FireArm")
        card_properties.hit_flags = card_properties.hit_flags & Hit.NoCounter
        return Action.from_card(player, card_properties)
    end

    soul_guts.charged_attack_func = function(self)
        local action = Action.new(player, "CHARACTER_SPECIAL")
        local field = player:field()

        action.on_execute_func = function()
            local spell = Spell.new(player:team())
            spell:set_tile_highlight(Highlight.Flash)

            overlay_animation:set_state("DEFAULT")
            overlay_animation:set_playback(Playback.Once)
            overlay_animation:apply(overlay)

            local facing = player:facing()
            spell:set_hit_props(
                HitProps.new(
                    60,
                    Hit.Impact | Hit.NoCounter,
                    Element.None,
                    Element.None,
                    player:context(),
                    Drag.None
                )
            )
            local can_spell_attack = false

            spell.on_update_func = function(self)
                if can_spell_attack == true then self:attack_tile() end
            end

            action:add_anim_action(3, function()
                can_spell_attack = true

                spell:set_tile_highlight(Highlight.Solid)
            end)

            action.on_action_end_func = function()
                spell:erase()
            end

            spell.on_attack_func = function(self, other)
                if Obstacle.from(other) == nil then return end
                other:hit(
                    HitProps.new(
                        0,
                        Hit.None | Hit.Drag,
                        Element.None,
                        Element.None,
                        player:context(),
                        Drag.new(facing, 1)
                    )
                )
            end

            local tile = player:current_tile():get_tile(facing, 1)
            field:spawn(spell, tile)
        end

        return action
    end

    soul_roll.charged_attack_func = function()
        local action = Action.new(player, "CHARACTER_SPECIAL")

        action:set_lockout(ActionLockout.new_animation())

        action.on_execute_func = function(self, user)
            Resources.play_audio(roll_arrow_audio)

            local facing = user:facing()

            local do_attack = function()
                local spell = Spell.new(user:team())
                local direction = facing

                spell:set_facing(facing)
                spell:set_texture(roll_arrow_texture)

                spell:set_elevation(27)
                spell:set_offset(-15, 0)

                local spell_anim = spell:animation()
                spell_anim:load(roll_arrow_animation_path)
                spell_anim:set_state("DEFAULT")

                spell._slide_started = false

                local hit_props = HitProps.new(
                    30,
                    Hit.Impact | Hit.Flinch | Hit.Flash,
                    Element.None,
                    user:context(),
                    Drag.None
                )

                spell:set_hit_props(hit_props)

                spell.on_update_func = function(self)
                    local tile = self:current_tile()
                    tile:attack_entities(self)
                    if not self:is_sliding() then
                        if tile:is_edge() and self._slide_started then
                            self:erase()
                        end

                        local dest = self:get_tile(direction, 1)
                        local ref = self
                        self:slide(dest, 5, function() ref._slide_started = true end)
                    end
                end

                spell.on_attack_func = function(self, other)
                    if Character.from(other) == nil and Player.from(other) == nil then return end

                    for i = 1, #other:field_cards(), 1 do
                        other:remove_field_card(i)
                    end
                end

                spell.on_collision_func = function(self, other)
                    local fx = Artifact.new()
                    fx:set_texture(roll_arrow_hit_texture)

                    local fx_anim = fx:animation()
                    fx_anim:load(roll_arrow_hit_animation_path)
                    fx_anim:set_state("DEFAULT")
                    fx_anim:on_complete(function()
                        fx:erase()
                    end)

                    fx:set_offset(math.random(-12, 12), math.random(-8, 8))

                    other:field():spawn(fx, other:current_tile())

                    self:erase()
                end

                spell:set_tile_highlight(Highlight.Solid)

                spell.can_move_to_func = function(tile)
                    return true
                end

                user:field():spawn(spell, user:get_tile(facing, 1))
            end

            self:add_anim_action(2, do_attack)
        end
        return action
    end

    soul_wind.charged_attack_func = function()
        local props = CardProperties.from_package("BattleNetwork6.Class01.Standard.079")

        -- Customize the damage.
        props.damage = 50

        return Action.from_card(player, props)
    end

    soul_thunder.charged_attack_func = function()
        local props = CardProperties.from_package("BattleNetwork4.HiddenAbility.ZapRing")
        return Action.from_card(player, props)
    end

    soul_search.charged_attack_func = function()
        local field = player:field()
        local enemy_filter = function(character)
            return character:team() ~= player:team()
        end
        -- Find an enemy to attack.
        local enemy_list = field:find_nearest_characters(player, enemy_filter)
        -- If one exists, start the scope attack.
        if #enemy_list > 0 then
            local action = Action.new(player, "SEARCH_RIFLE")

            action:override_animation_frames(
                {
                    { 1, 7 },
                    { 1, 1 },
                    { 2, 3 },
                    { 3, 3 },
                    { 2, 3 },
                    { 3, 3 },
                    { 2, 3 },
                    { 3, 3 },
                    { 2, 3 },
                    { 3, 3 },
                    { 2, 3 },
                    { 3, 3 },
                    { 1, 1 }
                }
            )

            action:set_lockout(ActionLockout.new_animation())

            action.on_action_end_func = function(self)
                player._cursor:erase() -- Erase the cursor if interrupted or action finishes
            end

            action.on_execute_func = function(self, user)
                -- Assign the cursor to the player for later erasure
                player._cursor = create_cursor()

                local target = enemy_list[1]
                local tile = target:current_tile()

                -- Spawn the cursor.
                field:spawn(player._cursor, target:current_tile())

                -- Hit Props are necessary to deal damage.
                local damage_props = HitProps.new(
                    10,
                    Hit.Impact | Hit.Flinch | Hit.PierceInvis | Hit.RetainIntangible,
                    Element.Cursor,
                    player:context(),
                    Drag.None
                )

                for i = 2, 10, 2 do
                    self:add_anim_action(i, function()
                        -- Play the gun sound.
                        Resources.play_audio(search_rifle_audio)

                        -- If the target exists, spawn the hitbox. We don't want to spawn it otherwise.
                        -- That's because the hitbox will linger and hit something else.
                        if not target:deleted() and not target:will_erase_eof() then
                            -- Make it our team.
                            local hitbox = Hitbox.new(user:team())

                            -- Update the props for the final hit.
                            if i == 10 then
                                damage_props.flags = damage_props.flags & ~Hit.RetainIntangible | Hit.Flash
                            end

                            -- Use the props for damage.
                            hitbox:set_hit_props(damage_props)

                            -- Spawn it!
                            field:spawn(hitbox, tile)
                        end
                    end)
                end
            end
            return action
        else
            -- Just shoot if you can't find an enemy lol.
            return Buster.new(player, false, player:attack_level())
        end
    end

    -- Special Attack Functions
    player.special_attack_func = function() end

    soul_aqua.special_attack_func = function(self) end

    soul_number.special_attack_func = function(self) end

    soul_metal.special_attack_func = function(self) end

    soul_wood.special_attack_func = function(self) end

    soul_junk.special_attack_func = function(self) end

    soul_blues.special_attack_func = function()
        if shield_cooldown > 0 then return end

        shield_cooldown = 40 + shield:duration()
        local hit = false

        return shield:create_action(player, function()
            Resources.play_audio(shield_impact_sfx)

            if hit then
                return
            end

            shield_reflect:spawn_spell(player, 50)
            hit = true
        end)
    end

    soul_fire.special_attack_func = function(self) end
    soul_guts.special_attack_func = function(self) end
    soul_roll.special_attack_func = function(self) end
    soul_wind.special_attack_func = function(self) end
    soul_thunder.special_attack_func = function(self) end
    soul_search.special_attack_func = function(self) end

    -- Misc Functions
    soul_aqua.calculate_charge_time_func = function(self)
        return 20
    end

    soul_thunder.calculate_charge_time_func = function(self)
        return 120
    end

    -- Update Functions
    soul_aqua.on_update_func = function(self)

    end

    soul_number.on_update_func = function(self)
        if player:animation():state() ~= "CHARACTER_IDLE" then
            overlay:hide()
        else
            overlay:reveal()
            overlay_animation:update()
            overlay_animation:apply(overlay)
        end
    end

    soul_metal.on_update_func = function(self)

    end

    soul_wood.on_update_func = function(self)

    end

    soul_junk.on_update_func = function(self)

    end

    soul_blues.on_update_func = function(self)
        if shield_cooldown > 0 then
            shield_cooldown = shield_cooldown - 1
        end
    end

    soul_fire.on_update_func = function(self)
        -- Overlay handling
        local player_state = player:animation():state()
        local overlay_state = overlay_animation:state()

        if not overlay_animation:has_state(player_state) then
            if string.find(player_state, "CHARACTER_MOVE") ~= nil then
                player_state = "CHARACTER_MOVE"
            else
                overlay:hide()
            end
        end

        if overlay_animation:has_state(player_state) then
            if overlay_state ~= player_state then
                overlay_animation:set_state(player_state)
            end
            overlay_animation:set_playback(Playback.Loop)
            overlay:reveal()
            overlay_animation:update()
            overlay_animation:apply(overlay)
        end

        -- Lava Panel healing
        local player_tile = player:current_tile()
        if player_tile and player_tile:state() == TileState.Lava then
            player_tile:set_state(TileState.Normal)
            player:set_health(player:health() + 50)
            create_recov()
        end
    end

    soul_guts.on_update_func = function(self)
        if player:input_has(Input.Pulsed.Shoot) or player:input_has(Input.Pressed.Shoot) then
            mash_count = mash_count + 1
            guts_timer = 0
        end

        if mash_count == 6 then
            guts_timer = 0
            mash_count = 0

            local action = GutsBuster.new(player, 10)

            player:queue_action(action)
        end

        guts_timer = guts_timer + 1

        if guts_timer > 10 then
            guts_timer = 0
            mash_count = 0
        end


        if player:animation():state() ~= "CHARACTER_SPECIAL" then
            overlay:hide()
        else
            overlay:reveal()
            overlay_animation:update()
            overlay_animation:apply(overlay)
        end
    end

    soul_roll.on_update_func = function(self)

    end

    soul_wind.on_update_func = function(self)
        if player:ignoring_hole_tiles() == false then
            player:ignore_hole_tiles(true)
        end

        if player:ignoring_negative_tile_effects() == false then
            player:ignore_negative_tile_effects(true)
        end

        if TurnGauge.frozen() then return end

        wind_timer = wind_timer + 1
        if wind_timer % 2 and not wind_spawned then
            if wind_list_index > 3 then
                local shuffled = {}

                for i = 1, #wind_list, 1 do
                    local pos = math.random(1, #shuffled + 1)
                    table.insert(shuffled, pos, wind_list[i])
                end

                wind_list = {}

                for i = 1, #shuffled, 1 do
                    table.insert(wind_list, shuffled[i])
                end

                wind_list_index = 1
            end

            create_wind_gust(wind_list[wind_list_index])

            wind_list_index = wind_list_index + 1

            wind_spawned = true
        end
    end

    soul_thunder.on_update_func = function(self)

    end

    soul_search.on_update_func = function(self)

    end

    -- Soul Unison Button Functions
    local function obey_rules(count, item)
        local has_regular_card = player:has_regular_card()
        local state = "INACTIVE"

        -- Cannot unify if there are no staged items.
        if count < 1 then return state end

        -- Cannot unify the staged item is somehow nothing.
        if item == nil then return state end

        -- Cannot unify if Anxious or Evil
        if match_emotion() == false then return state end

        -- Cannot unify using a Regular Chip.
        if item.category == "deck_card" and item.index == 1 and has_regular_card == true then return state end

        local card_properties;
        if item.category == "deck_card" then
            card_properties = player:deck_card_properties(item.index)
        elseif item.category == "card" then
            card_properties = item.card_properties
        end

        -- Cannot unify if the card properties are somehow invalid.
        if card_properties == nil then return state end

        for _, value in ipairs(chosen_souls) do
            if value.used == true then goto continue end

            -- Obey element matching rules for all Souls
            local element_match = match_element(card_properties, { value.element }, false)
            if element_match == false then goto continue end

            -- Obey Recovery rules for Roll Soul
            if value.recover == true and card_properties.recover <= 0 then goto continue end

            -- Obey Hit Flag rules for Guts Soul
            if value.hit_flag ~= nil and card_properties.hit_flags & Hit.PierceGround == 0 then goto continue end

            readied_form = value
            state = "ACTIVE"

            ::continue::
        end


        return state
    end

    create_version_selector(unison_button, { "SELECT_RS", "SELECT_BM" }, function(selected_state)
        if selected_state == "SELECT_RS" then
            chosen_souls = choose_souls(red_sun_souls, unison_button)
        elseif selected_state == "SELECT_BM" then
            chosen_souls = choose_souls(blue_moon_souls, unison_button)
        end

        unison_button.on_selection_change_func = function(self)
            -- Cannot stage two souls at once.
            if is_soul_staged == true then
                return
            end

            local count = #player:staged_items()
            local item = player:staged_item(count)

            -- Feed the above values in to a rule checking function.
            local state = obey_rules(count, item)

            self:animation():set_state(state)
        end

        unison_button.use_func = function(self)
            if chosen_souls ~= nil and readied_form ~= nil then
                handle_staging_form()

                self:animation():set_state("INACTIVE")

                readied_form = nil

                return true
            end

            return false
        end
    end)
end
