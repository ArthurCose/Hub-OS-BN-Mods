function augment_init(augment)
  local player = augment:owner()
  -- Boost by ten minus current hand size to set up having 10 chips.
  player:boost_hand_size(10 - player:hand_size());
end
