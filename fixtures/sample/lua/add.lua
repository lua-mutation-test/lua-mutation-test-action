--- Sample fixture for smoke-testing the action.
local M = {}

--- Add two numbers (mutants: `+` -> `-`, `*`, `/`).
---@param a number
---@param b number
---@return number
function M.add(a, b)
  return a + b
end

--- Return true when n is zero (mutants: `==` -> `~=`, `>`, ...).
---@param n number
---@return boolean
function M.is_zero(n)
  return n == 0
end

--- Return n when inside [lo, hi], else nil (mutants: `or` -> `and`).
---@param n number
---@param lo number
---@param hi number
---@return number|nil
function M.clamp(n, lo, hi)
  if n < lo or n > hi then
    return nil
  end
  return n
end

return M
