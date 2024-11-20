---@diagnostic disable: inject-field
local USE_SFX = Resources.load_audio("use_shuffle.ogg")
local SHUFFLE_SFX = Resources.load_audio("shuffle.wav")
local PREVIEW_TEXTURE = Resources.load_texture("preview.png")
local BUTTON_TEXTURE = Resources.load_texture("button.png")

---@param player Entity
local function resolve_blocked_slots(player)
  local staged_items = player:staged_items()
  local blocked_slots = {}

  for _, item in ipairs(staged_items) do
    if item.category == "deck_card" or item.category == "deck_discard" then
      blocked_slots[item.index] = true
    end
  end

  if player:has_regular_card() then
    blocked_slots[1] = true
  end

  return blocked_slots
end

---@param player Entity
---@return number[]
local function resolve_unblocked_slots(player, deck)
  local blocked_slots = resolve_blocked_slots(player)
  local slots = {}

  for i = 1, #deck do
    if not blocked_slots[i] then
      slots[#slots + 1] = i
    end
  end

  return slots
end

---@param player Entity
---@param deck table
---@param index_a number
---@param index_b number
local function swap_card(player, deck, index_a, index_b)
  if index_a == index_b then
    return
  end

  local card_a = deck[index_a]
  local card_b = deck[index_b]

  player:set_deck_card(index_a, card_b)
  player:set_deck_card(index_b, card_a)

  deck[index_a] = card_b
  deck[index_b] = card_a
end

---@param augment Augment
function augment_init(augment)
  local player = augment:owner()

  local button = augment:create_card_button(2)
  button:use_default_audio(false)
  button:set_texture(BUTTON_TEXTURE)
  button:set_preview_texture(PREVIEW_TEXTURE)

  local animation = button:animation()
  animation:load("button.animation")

  local used_count = 0

  local open_component = player:create_component(Lifetime.CardSelectOpen)
  open_component.on_update_func = function()
    animation:set_state("DEFAULT")
    used_count = 0
  end

  augment.on_delete_func = function(self)
    if open_component ~= nil then open_component:eject() end
  end

  button.use_func = function()
    if used_count >= augment:level() then
      return false
    end

    used_count = used_count + 1

    animation:set_state("USED")

    player:set_card_selection_blocked(true)
    player:play_audio(USE_SFX)

    local component = player:create_component(Lifetime.Scene)
    local hand_size = player:hand_size()
    local deck = player:deck_cards()
    local free_slots = resolve_unblocked_slots(player, deck)

    local TOTAL_SHUFFLES = 8
    local INTERVAL = 4

    local ticks = 0

    component.on_update_func = function()
      ticks = ticks + 1

      if ticks % INTERVAL ~= 0 then
        -- idle
        return
      end

      -- shuffle
      player:play_audio(SHUFFLE_SFX)

      for _, index_a in ipairs(free_slots) do
        if index_a > hand_size then
          -- no need to shuffle cards we can't see
          break
        end

        local index_b = free_slots[math.random(#free_slots)]

        swap_card(player, deck, index_a, index_b)
      end

      if ticks < TOTAL_SHUFFLES * INTERVAL then
        return
      end

      -- complete
      player:set_card_selection_blocked(false)

      if used_count >= augment:level() then
        animation:set_state("DISABLED")
      else
        animation:set_state("DEFAULT")
      end

      component:eject()
    end

    return true
  end
end
