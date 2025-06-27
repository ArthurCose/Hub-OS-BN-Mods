---@class dev.konstinople.library.iterator
local IteratorLib = {}

---Limits the output of an iterator, by taking only `amount` values from it.
---
---### Example
---```lua
----- iterator that outputs "a" five times
---local iter = IteratorLib.take(5, function() return "a" end)
---
----- print the output
---for value in iter do
---  print(value)
---end
---```
---@generic T
---@param amount number
---@param iter fun(): T?
---@return fun(): T?
function IteratorLib.take(amount, iter)
  return function()
    if amount <= 0 then
      return
    end

    amount = amount - 1
    return iter()
  end
end

---Combines a variable amount of iterators into a single iterator.
---
---### Example
---```lua
---local iter = IteratorLib.chain(
---  -- iterator that repeats "a" five times before completing
---  IteratorLib.take(5, function() return "a" end),
---  -- iterator that outputs "b" once
---  IteratorLib.take(1, function() return "b" end)
---)
---
----- print the output
---for value in iter do
---  print(value)
---end
---```
function IteratorLib.chain(...)
  local iters = { ... }

  local i = 1
  local iter = iters[i]

  return function()
    while iter do
      local output = iter()

      if output ~= nil then
        return output
      end

      i = i + 1
      iter = iters[i]
    end
  end
end

---Similar to `chain`,
---
---### Example
---```lua
---local iter = IteratorLib.short_circuiting_chain(
---  -- iterator that outputs "a" once
---  IteratorLib.take(1, function() return "a" end),
---  -- iterator that outputs nothing, failing the rest of the chain
---  IteratorLib.take(0, function() return "b" end),
---  -- never seen, unless we take at least 1 from the above iterator
---  IteratorLib.take(1, function() return "c" end)
---)
---
----- print the output
---for value in iter do
---  print(value)
---end
---```
function IteratorLib.short_circuiting_chain(...)
  local iters = { ... }

  local i = 1
  local iter = iters[i]
  local iter_success = false

  return function()
    while iter do
      local output = iter()

      if output ~= nil then
        iter_success = true
        return output
      elseif not iter_success then
        iter = nil
        return nil
      end

      i = i + 1
      iter = iters[i]
      iter_success = false
    end
  end
end

---Takes iterators that return iterators,
---and outputs just the return values of those iterators.
---
---### Example
---```lua
----- repeats "a" then "b" five times,
----- by flattening an iterator that returns iterators
----- into an iterator that just returns the values
---local iter = IteratorLib.flatten(
---  -- create an iterator that outputs iterators five times
---  IteratorLib.take(2, function()
---    -- output an iterator that outputs "a" then "b"
---    return IteratorLib.chain(
---      IteratorLib.take(1, function() return "a" end),
---      IteratorLib.take(1, function() return "b" end)
---    )
---  end)
---)
---
----- print the output
---for value in iter do
---  print(value)
---end
---```
---@generic T
---@param iter fun(): nil | fun(): T
---@return fun(): T?
function IteratorLib.flatten(iter)
  local inner_iter = iter()

  return function()
    while inner_iter do
      local output = inner_iter()

      if output ~= nil then
        return output
      end

      inner_iter = iter()
    end
  end
end

return IteratorLib
