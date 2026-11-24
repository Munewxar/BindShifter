local loader = require("loader")

describe("Diff", function()
	local Diff
	before_each(function()
		Diff = loader.loadCore().Diff
	end)

	it("computes added, changed and removed keys", function()
		local live = { ["1"] = "A", ["2"] = "B", ["3"] = "C" }
		local target = { ["1"] = "A", ["2"] = "X", ["4"] = "D" }
		local d = Diff.compute(live, target)
		assert.same({ ["4"] = "D" }, d.added)
		assert.same({ ["2"] = { from = "B", to = "X" } }, d.changed)
		assert.same({ ["3"] = "C" }, d.removed)
		assert.equal(3, d.count)
	end)

	it("frees every key for an empty profile", function()
		local d = Diff.compute({ ["1"] = "A", ["2"] = "B" }, {})
		assert.equal(2, d.count)
		assert.same({ ["1"] = "A", ["2"] = "B" }, d.removed)
	end)

	it("is empty when live equals target", function()
		assert.equal(0, Diff.compute({ ["1"] = "A" }, { ["1"] = "A" }).count)
	end)

	describe("with shared commands", function()
		local function isCommon(cmd)
			return cmd == "TARGET" or cmd == "MOVE"
		end

		it("never touches live shared bindings", function()
			local d = Diff.compute({ TAB = "TARGET", ["1"] = "A" }, { ["1"] = "A" }, isCommon)
			assert.equal(0, d.count)
		end)

		it("skips shared commands stored in the profile", function()
			local d = Diff.compute({}, { W = "MOVE", ["1"] = "A" }, isCommon)
			assert.same({ W = "MOVE" }, d.skippedCommon)
			assert.same({ ["1"] = "A" }, d.added)
		end)

		it("reports a conflict when the key is taken by a shared binding", function()
			local d = Diff.compute({ TAB = "TARGET" }, { TAB = "A" }, isCommon)
			assert.same({ TAB = { profile = "A", common = "TARGET" } }, d.conflicts)
			assert.equal(0, d.count)
		end)
	end)

	it("drops ignored keys from a diff", function()
		local d = Diff.compute({ ["1"] = "A", ["2"] = "B" }, {})
		Diff.without(d, { ["1"] = "X" })
		assert.equal(1, d.count)
		assert.is_nil(d.removed["1"])
	end)
end)
