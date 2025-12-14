local bn_assets = require("BattleNetwork.Assets")
local audio = bn_assets.load_audio("deltaray_beep.ogg")
function card_init(actor, props)
    local action = Action.new(actor, "CHARACTER_IDLE");

    local step = action:create_step()

    action:set_lockout(ActionLockout.new_sequence())

    action.on_execute_func = function(self, user)
        local lime = Color.new(0, 255, 0)
        local black = Color.new(0, 0, 0)
        local comp = user:create_component(Lifetime.Battle)

        local time = 16
        local sprite = user:sprite()
        Resources.play_audio(audio, AudioBehavior.NoOverlap)
        comp.on_update_func = function(self)
            if time >= 32 then
                user:boost_augment("BattleNetwork6.Program13.UnderShirt", 1)
                step:complete_step()
                action:end_action()
                self:eject()
                return
            end

            local progress = math.abs(time % 32 - 16) / 16
            time = time + 1

            sprite:set_color_mode(ColorMode.Additive)
            sprite:set_color(Color.mix(lime, black, progress))
        end
    end

    return action;
end
