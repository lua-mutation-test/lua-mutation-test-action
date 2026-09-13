-- Busted specs for fixtures/sample/lua/add.lua.
-- Run from fixtures/sample so `require("lua.add")` resolves to lua/add.lua.
-- One STRONG spec (kills mutants) and one intentionally WEAK spec
-- (lets a mutant survive); clamp() has no specs, so its `or` mutant survives.
local add = require("lua.add")

describe("sample fixture", function()
  describe("add() — strong spec (kills mutants)", function()
    it("adds two numbers", function()
      assert.are.equal(3, add.add(1, 2))
      assert.are.equal(0, add.add(1, -1))
      assert.are.equal(-5, add.add(-2, -3))
    end)
  end)

  describe("is_zero() — intentionally weak spec (lets a mutant survive)", function()
    it("returns a non-nil value for zero", function()
      -- Deliberately weak: passes for both `n == 0` (true) and the
      -- `n ~= 0` mutant (false), since neither is nil.
      assert.is_not_nil(add.is_zero(0))
    end)
  end)

  -- NOTE: clamp() is untested on purpose, so its `or` -> `and` mutant survives.
end)
