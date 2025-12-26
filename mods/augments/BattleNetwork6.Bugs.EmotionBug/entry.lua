---@param augment Augment
function augment_init(augment)
  local player = augment:owner()
  local bug_aux_prop = AuxProp.new()
      :require_interval(60)
      :with_callback(function()
        local chance = math.floor(math.random(1, 16))
        local normal_emotion_name = "DEFAULT"
        local synchro_emotion_name = "SYNCHRO"
        local anger_emotion_name = "ANGER"
        local tired_emotion_name = "TIRED"

        local normal_emotion_table = {
          { emotion = tired_emotion_name,   range = 14 },
          { emotion = anger_emotion_name,   range = 15 },
          { emotion = synchro_emotion_name, range = 16 }
        }
        local tired_emotion_table = {
          { emotion = normal_emotion_name,  range = 14 },
          { emotion = anger_emotion_name,   range = 15 },
          { emotion = synchro_emotion_name, range = 16 },
        }
        local angry_emotion_table = {
          { emotion = normal_emotion_name,  range = 7 },
          { emotion = tired_emotion_name,   range = 15 },
          { emotion = synchro_emotion_name, range = 16 },
        }
        local synchro_emotion_table = {
          { emotion = normal_emotion_name, range = 7 },
          { emotion = tired_emotion_name,  range = 15 },
          { emotion = anger_emotion_name,  range = 16 },
        }

        local table_of_tables = {}
        table_of_tables[normal_emotion_name] = normal_emotion_table
        table_of_tables[tired_emotion_name] = tired_emotion_table
        table_of_tables[anger_emotion_name] = angry_emotion_table
        table_of_tables[synchro_emotion_name] = synchro_emotion_table

        local current_emotion = player:emotion()
        local chosen_table = table_of_tables[current_emotion]

        if chosen_table == nil then return end

        for index, value in ipairs(chosen_table) do
          if chance <= value.range then
            player:set_emotion(value.emotion)
            break
          end
        end
      end)

  player:add_aux_prop(bug_aux_prop)

  augment.on_delete_func = function()
    player:remove_aux_prop(bug_aux_prop)
  end
end
