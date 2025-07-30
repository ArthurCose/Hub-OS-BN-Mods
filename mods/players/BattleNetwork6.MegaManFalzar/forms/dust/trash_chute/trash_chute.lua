local CHUTE_SFX = Resources.load_audio("trash_chute.ogg") -- this also seems the same as deselecting a cross?
local COMPLETE_SFX = Resources.load_audio("use_shuffle.ogg")
local PREVIEW_TEXTURE = Resources.load_texture("preview.png")
local BUTTON_TEXTURE = Resources.load_texture("button.png")

---@param player Entity
---@param augment Entity | Augment | PlayerForm
return function(player, augment)
  local button = augment:create_card_button(2)
  button:use_default_audio(false)
  button:set_texture(BUTTON_TEXTURE)
  button:set_preview_texture(PREVIEW_TEXTURE)

  local animation = button:animation()
  animation:load("button.animation")

  local used = false

  local open_component = player:create_component(Lifetime.CardSelectOpen)
  open_component.on_update_func = function()
    animation:set_state("DEFAULT")
    used = false
  end

  button.use_func = function()
    local staged_items = player:staged_items()

    if used or #staged_items == 0 or staged_items[#staged_items].category ~= "deck_card" then
      return false
    end

    used = true

    animation:set_state("USED")
    player:set_card_selection_blocked(true)

    local component = player:create_component(Lifetime.Scene)
    local deck = player:deck_cards()

    local INTERVAL = 25
    local ticks = 0
    local trashed = {}

    component.on_update_func = function()
      local should_idle = ticks % INTERVAL ~= 0
      ticks = ticks + 1

      if should_idle then
        return
      end

      local item = staged_items[#staged_items - #trashed]

      if not item or item.category ~= "deck_card" then
        player:play_audio(COMPLETE_SFX)

        -- complete
        player:set_card_selection_blocked(false)
        animation:set_state("DISABLED")
        component:eject()

        -- sort and remove deck cards in reverse to avoid issues with shifting indices
        table.sort(trashed)

        for i = #trashed, 1, -1 do
          local deck_index = trashed[i]
          player:pop_staged_item()
          player:remove_deck_card(deck_index)
          player:insert_deck_card(9999, deck[deck_index])
        end

        return
      end

      -- trash
      player:play_audio(CHUTE_SFX)
      trashed[#trashed + 1] = item.index

      for _ = 1, #trashed do
        player:pop_staged_item()
      end

      for i = 1, #trashed do
        player:stage_deck_discard(trashed[i])
      end
    end

    return true
  end
end
