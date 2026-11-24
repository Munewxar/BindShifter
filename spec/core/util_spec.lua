local loader = require("loader")

describe("Util", function()
	local Util
	before_each(function()
		Util = loader.loadCore().Util
	end)

	it("deep copies nested tables", function()
		local src = { a = { b = 1 }, c = 2 }
		local copy = Util.deepCopy(src)
		assert.same(src, copy)
		copy.a.b = 5
		assert.equal(1, src.a.b)
	end)

	it("compares tables deeply", function()
		assert.is_true(Util.deepEqual({ a = { 1, 2 } }, { a = { 1, 2 } }))
		assert.is_false(Util.deepEqual({ a = 1 }, { a = 1, b = 2 }))
		assert.is_false(Util.deepEqual({ a = 1 }, "x"))
	end)

	it("trims whitespace", function()
		assert.equal("Raid", Util.trim("  Raid \n"))
		assert.equal("", Util.trim(nil))
	end)

	it("returns sorted keys and counts", function()
		assert.same({ "a", "b", "c" }, Util.sortedKeys({ c = 1, a = 1, b = 1 }))
		assert.equal(3, Util.count({ x = 1, y = 2, z = 3 }))
		assert.is_true(Util.isEmpty({}))
	end)

	it("counts UTF-8 characters", function()
		assert.equal(4, Util.utf8len("Рейд"))
		assert.equal(4, Util.utf8len("Raid"))
	end)

	it("lowercases ASCII and Cyrillic", function()
		assert.equal("рейд ёлка abc", Util.lower("РЕЙД ЁЛКА ABC"))
		assert.equal("пря", Util.lower("ПРЯ"))
	end)
end)
