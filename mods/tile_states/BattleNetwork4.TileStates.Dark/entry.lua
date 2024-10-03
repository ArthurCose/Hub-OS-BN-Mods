local AUDIO = Resources.load_audio("darkhole.ogg")
--@param custom_state CustomTileState
function tile_state_init(custom_state)
  -- yeah dark tiles kinda just sit there until something else counts them so...
  -- no effect needs to be written here lol.
  Resources.play_audio(AUDIO, AudioBehavior.NoOverlap)
end
