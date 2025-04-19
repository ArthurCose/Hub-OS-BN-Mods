local bn_assets = require("BattleNetwork.Assets")

local animation_path = "Catack Virus.animation"

local explosion_texture = bn_assets.load_texture("tank_cannon_blast.png")
local explosion_animation_path = bn_assets.fetch_animation_path("tank_cannon_blast.animation")

local impact_texture = bn_assets.load_texture("tank_cannon_hit_effect.png")
local impact_animation_path = bn_assets.fetch_animation_path("tank_cannon_hit_effect.animation")

local on_roll_sound = bn_assets.load_audio("tankcannon_mob_move.ogg")
local on_windup_sound = bn_assets.load_audio("tankcannon_mob_windup.ogg")

local on_spell_sound = bn_assets.load_audio("tankcannon_fire.ogg")

local on_impact_sound = bn_assets.load_audio("tankcannon_explode.ogg")

local create_boom = function(catack)
  local spell = Spell.new(catack:team())
  spell:set_facing(catack:facing())
  spell._slide_started = false
  local direction = spell:facing()
  spell:set_hit_props(
    HitProps.new(
      catack._attack,
      Hit.Impact | Hit.Drag | Hit.Flinch | Hit.Flash,
      Element.None,
      catack:context(),
      Drag.new(direction, 1)
    )
  )
  spell._can_slide = true
  spell._can_attack = true

  spell.on_update_func = function(self)
    if self._can_attack == true then self:attack_tile() end

    if self:is_sliding() == false and self._can_slide then
      local own_tile = self:current_tile();
      if not own_tile then return end
      if own_tile:get_tile(self:facing(), 1):is_edge() then
        self._can_slide = false
        if #self:current_tile():find_entities(catack._tile_query) == 0 then
          self:teleport(catack:field():tile_at(self:current_tile():x(), 2), function() end)

          self:set_texture(explosion_texture)

          self:sprite():set_layer(-2)

          local anim = self:animation()

          anim:load(explosion_animation_path)

          anim:set_state("DEFAULT")

          anim:apply(self:sprite())

          self:attack_tiles({ self:get_tile(Direction.Up, 1), self:get_tile(Direction.Down, 1) })

          anim:on_complete(function() self:delete() end)
        end
      end

      if self:current_tile():is_edge() and self._slide_started then self:delete() end

      local dest = self:get_tile(direction, 1)

      if not self._can_slide then return end

      local ref = self

      self:slide(dest, 1, function()
        ref._slide_started = true
      end)
    end
  end

  spell.on_collision_func = function(self, other)
    self._can_slide = false
    self._can_attack = false

    self:set_texture(impact_animation_path)

    self:sprite():set_layer(-2)

    local anim = self:animation()

    anim:load(impact_animation_path)
    anim:set_state("DEFAULT")

    anim:apply(self:sprite())

    anim:on_complete(function()
      self:delete()
    end)
  end

  spell.on_attack_func = function(self, other)
    self._can_slide = false
  end

  spell.on_delete_func = function(self)
    self:erase()
  end

  spell.can_move_to_func = function(tile)
    return true
  end

  Resources.play_audio(on_spell_sound)
  return spell
end

function character_init(catack)
  catack._cannon_sfx = bn_assets.load_audio("cannon.ogg")

  -- private variables
  catack._idle_state = "IDLE"
  catack._move_state = "MOVE"
  catack._windup_state = "ATTACK_WINDUP"
  catack._shoot_state = "SHOOT"
  catack._hide_state = "ATTACK_HIDE"

  catack._attack = 0
  catack._idle_between_strikes = 0
  catack._current_idle_time = 0

  catack._can_move = true
  catack._can_attack = false
  catack._do_once = true

  catack._offset_speed = 0
  catack._slide_speed = 0

  catack._destination_tile = nil

  catack._offsetting_forward = false
  catack._offsetting_reverse = false
  catack._continue_offsetting = false

  catack._tile_query = function(ent)
    if not ent then return false end
    if ent:deleted() or ent:will_erase_eof() then return false end
    if ent:id() == catack:id() then return false end
    return Character.from(ent) ~= nil or Obstacle.from(ent) ~= nil
  end

  -- meta
  catack:set_name("Catack")
  catack:set_height(36)

  --base color
  catack:set_texture(Resources.load_texture("Catack Virus.greyscaled.png"))
  local rank = catack:rank()

  if rank == Rank.V1 then
    catack:set_health(130)
    catack._idle_between_strikes = 180
    catack._current_idle_time = 180
    catack._attack = 70
    catack._offset_speed = 1
    catack._slide_speed = 60
    catack:set_palette(Resources.load_texture("catack_v1.palette.png"))
  elseif rank == Rank.V2 then
    catack:set_health(160)
    catack._idle_between_strikes = 150
    catack._current_idle_time = 150
    catack._attack = 100
    catack._offset_speed = 1
    catack._slide_speed = 60
    catack:set_palette(Resources.load_texture("catack_v2.palette.png"))
  elseif rank == Rank.V3 then
    catack:set_health(220)
    catack._idle_between_strikes = 120
    catack._current_idle_time = 120
    catack._attack = 150
    catack._offset_speed = 1
    catack._slide_speed = 60
    catack:set_palette(Resources.load_texture("catack_v3.palette.png"))
  elseif rank == Rank.SP then
    catack:set_health(300)
    catack._idle_between_strikes = 60
    catack._current_idle_time = 60
    catack._attack = 200
    catack._offset_speed = 1
    catack._slide_speed = 60
    catack:set_palette(Resources.load_texture("catack_sp.palette.png"))
  end

  local anim = catack:animation()

  anim:load(animation_path)

  anim:set_state(catack._idle_state)

  anim:set_playback(Playback.Loop)

  catack:add_aux_prop(StandardEnemyAux.new())

  -- setup event hanlders
  catack.on_update_func = function(catack)
    if catack._current_idle_time <= 0 then
      if catack._can_move then
        catack._destination_tile = catack:get_tile(catack:facing(), 1)

        if catack._do_once then
          catack._do_once = false

          Resources.play_audio(on_roll_sound)

          if catack._destination_tile:team() ~= catack:team() then
            catack._destination_tile:set_team(catack:team(), catack:facing())
          end

          anim:set_state(catack._move_state)

          anim:set_playback(Playback.Loop)
        end

        if catack._destination_tile:x() == 1 or catack._destination_tile:x() == 6 or #catack._destination_tile:find_entities(catack._tile_query) > 0 or catack._continue_offsetting then
          if catack:facing() == Direction.Left then
            if catack:offset().x <= -40 or catack._offsetting_reverse then
              catack._offsetting_reverse = true
              catack:set_offset(catack:offset().x + catack._offset_speed * 0.5, 0)
              if catack:offset().x == 0 then
                catack._offsetting_reverse = false
                catack._continue_offsetting = false
                catack._windup_state = "REVERSE_WINDUP"
                catack:set_offset(0, 0)
              end
            elseif catack:offset().x >= -40 and not catack._offsetting_reverse then
              catack._continue_offsetting = true
              catack:set_offset(catack:offset().x - catack._offset_speed * 0.5, 0)
              if catack:offset().x == -40 then
                local hitbox = Hitbox.new(catack:team())
                hitbox:set_hit_props(
                  HitProps.new(
                    10,
                    Hit.Impact | Hit.Flinch,
                    Element.None,
                    catack:context(),
                    Drag.None
                  )
                )
                catack:field():spawn(hitbox, catack._destination_tile)
              end
            end
          elseif catack:facing() == Direction.Right then
            if catack:offset().x >= 40 or catack._offsetting_reverse then
              catack._offsetting_reverse = true
              catack:set_offset(catack:offset().x - catack._offset_speed * 0.5, 0)
              if catack:offset().x == 0 then
                catack._offsetting_reverse = false
                catack._continue_offsetting = false
                catack._windup_state = "REVERSE_WINDUP"
                catack:set_offset(0, 0)
              end
            elseif catack:offset().x < 40 and not catack._offsetting_reverse then
              catack._continue_offsetting = true
              catack:set_offset(catack:offset().x + catack._offset_speed * 0.5, 0)
              if catack:offset().x == -40 then
                local hitbox = Hitbox.new(catack:team())
                hitbox:set_hit_props(
                  HitProps.new(
                    10,
                    Hit.Impact | Hit.Flinch,
                    Element.None,
                    catack:context(),
                    Drag.None
                  )
                )
                catack:field():spawn(hitbox, catack._destination_tile)
              end
            end
          end
          if not catack._continue_offsetting and catack:offset().x == 0 then
            catack._offsetting_forward = false
            catack._offsetting_reverse = false
            catack._destination_tile = catack:current_tile()
          end
        else
          catack:slide(catack._destination_tile, (catack._slide_speed), (10), function() end)
        end
        if not catack._continue_offsetting then
          catack._can_move = false
          catack._can_attack = true
          catack._do_once = true
        end
      end
      if catack._can_attack then
        if catack:current_tile() == catack._destination_tile then
          if catack._do_once then
            local anim = catack:animation()
            Resources.play_audio(on_windup_sound)
            anim:set_state(catack._windup_state)
            anim:set_playback(Playback.Once)
            anim:on_complete(function()
              anim:set_state(catack._shoot_state)
              anim:set_playback(Playback.Once)
              anim:on_frame(3, function()
                local boom = create_boom(catack)
                catack:field():spawn(boom, catack:get_tile(catack:facing(), 1))
                anim:set_state(catack._hide_state)
                anim:set_playback(Playback.Once)
                anim:on_complete(function()
                  anim:set_state(catack._idle_state)
                  anim:set_playback(Playback.Loop)
                  catack._can_move = true
                  catack._can_attack = false
                  catack._do_once = true
                  catack._current_idle_time = catack._idle_between_strikes
                  catack._windup_state = "ATTACK_WINDUP"
                end)
              end)
            end)
            catack._do_once = false
          end
        end
      end
    else
      catack._current_idle_time = catack._current_idle_time - 1
    end
  end

  catack.on_delete_func = function(self)
    self:default_character_delete()
  end
end
