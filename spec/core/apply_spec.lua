local loader = require("loader")
local FakeWow = require("fake_wow")

describe("Apply", function()
	local ns, fake
	before_each(function()
		ns = loader.loadCore()
		fake = FakeWow.new({ bindings = { ["1"] = "ACTIONBUTTON1", ["2"] = "ACTIONBUTTON2", ["3"] = "JUMP" } })
	end)

	local function apply(target, set)
		local diff = ns.Diff.compute(ns.Snapshot.capture(fake.api), target)
		return ns.Apply.run(fake.api, diff, set or "character")
	end

	it("makes live bindings exactly equal to the target", function()
		local target = { ["1"] = "ACTIONBUTTON1", ["2"] = "ACTIONBUTTON5", ["Q"] = "SPELL Frostbolt" }
		local report = apply(target)
		assert.same(target, fake.bindings())
		assert.equal(3, report.changed)
		assert.same({}, report.issues)
	end)

	it("switches to the target set first, then saves once into it", function()
		-- The client starts on the account set.
		apply({ ["1"] = "JUMP" }, "character")
		assert.same({ "character", "character" }, fake.state.saves)
		assert.equal("character", fake.state.active)
		apply({ ["1"] = "JUMP", ["2"] = "JUMP" }, "character")
		assert.same({ "character", "character", "character" }, fake.state.saves)
	end)

	it("keeps intermediate saves by other addons in the target set", function()
		-- Emulates Bartender4 saving to the current set on every binding change.
		local real = fake.api.setBinding
		fake.api.setBinding = function(key, cmd)
			local ok = real(key, cmd)
			fake.api.saveBindings(fake.api.currentBindingSet())
			return ok
		end
		local accountBefore = fake.state.sets.account
		apply({ ["1"] = "JUMP" }, "character")
		assert.same(accountBefore, fake.state.sets.account)
		assert.equal("JUMP", fake.state.sets.character["1"])
	end)

	it("reports bindings the client rejects", function()
		local report = apply({ ["1"] = "NOSUCHCOMMAND" })
		assert.equal("rejected", report.issues[1].reason)
		assert.equal("1", report.issues[1].key)
	end)

	it("reports post-check mismatches when the client ignores a binding", function()
		local real = fake.api.setBinding
		fake.api.setBinding = function(key, cmd)
			if key == "Q" then
				return true -- claims success, does nothing
			end
			return real(key, cmd)
		end
		local report = apply({ Q = "SPELL Frostbolt" })
		local reasons = {}
		for _, i in ipairs(report.issues) do
			reasons[i.key] = i.reason
		end
		assert.equal("postcheckMismatch", reasons.Q)
	end)
end)
