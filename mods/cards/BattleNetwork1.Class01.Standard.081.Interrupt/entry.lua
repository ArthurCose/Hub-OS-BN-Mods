local bn_assets = require("BattleNetwork.Assets")
local TEXTURE = bn_assets.load_texture("bn1_interrupt.png")
local ANIM_PATH = bn_assets.fetch_animation_path("bn1_interrupt.animation")

function card_init(user, props)
	local action = Action.new(user)
	action:set_lockout(ActionLockout.new_sequence())

	local interrupt_action = function(entity)
		local interrupt = Artifact.new()

		local interrupt_sprite = interrupt:sprite()
		interrupt_sprite:set_texture(TEXTURE)

		interrupt:set_elevation(math.ceil(entity:height() * 0.5))

		local interrupt_animation = interrupt:animation()
		interrupt_animation:load(ANIM_PATH)
		interrupt_animation:set_state("DEFAULT")
		interrupt_animation:on_complete(function()
			for i = 1, #entity:field_cards(), 1 do
				entity:remove_field_card(i)
			end

			interrupt:erase()
		end)

		Field.spawn(interrupt, entity:current_tile())
	end

	action.on_execute_func = function()
		local step = action:create_step()
		local timer = 80

		local characters = Field.find_characters(function(ch)
			if not ch:spawned() then return false end
			if ch:deleted() or ch:will_erase_eof() then return false end
			if ch:team() == user:team() then return false end
			return true
		end)

		for i = 1, #characters, 1 do
			interrupt_action(characters[i])
		end

		step.on_update_func = function()
			if timer <= 0 then
				step:complete_step()
				return
			end

			timer = timer - 1
		end
	end

	return action
end
