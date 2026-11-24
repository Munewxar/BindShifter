local Env = require("env")

describe("Service: manual changes (US3)", function()
	local env, s
	before_each(function()
		env = Env.new({ bindings = { ["1"] = "ACTIONBUTTON1", ["2"] = "ACTIONBUTTON2", TAB = "TARGETNEARESTENEMY" } })
		s = env.service
		s:saveCurrent("A")
	end)

	it("has no mark right after saving or applying", function()
		assert.equal(0, s:dirtyCount())
	end)

	it("counts manual changes and never changes the profile by itself", function()
		env.fake.bind("1", "JUMP")
		env.fake.bind("3", "ACTIONBUTTON3")
		assert.equal(2, s:dirtyCount())
		assert.equal("ACTIONBUTTON1", s:getProfile("A").bindings["1"])
		local diff = s:dirtyDiff()
		assert.same({ ["3"] = "ACTIONBUTTON3" }, diff.removed)
		assert.same({ ["1"] = { from = "JUMP", to = "ACTIONBUTTON1" } }, diff.changed)
	end)

	it("saves changes into the active profile with a backup (SC-010)", function()
		env.fake.bind("1", "JUMP")
		local count = #env.db.chars["Tester - Realm"].history
		assert.equal("done", s:saveToProfile().step)
		assert.equal(0, s:dirtyCount())
		assert.equal("JUMP", s:getProfile("A").bindings["1"])
		assert.equal(count + 1, #env.db.chars["Tester - Realm"].history)
		assert.equal("saveToProfile", s:listHistory()[1].op)
	end)

	it("reverts through the normal apply flow", function()
		env.fake.bind("1", "JUMP")
		local step = s:revertToProfile()
		assert.equal("preview", step.step)
		s:confirmApply(step)
		assert.equal(0, s:dirtyCount())
	end)

	it("ignores shared bindings", function()
		s:setCommonGroup("TARGETING", true)
		env.fake.bind("TAB", nil)
		env.fake.bind("F1", "TARGETNEARESTENEMY")
		assert.equal(0, s:dirtyCount())
	end)

	it("ignores keys that are inactive in the current mode", function()
		local p = s:getProfile("A")
		p.inactive = { ["5"] = "CLICK BT4Button13:LeftButton" }
		env.fake.bind("5", "JUMP")
		assert.equal(0, s:dirtyCount())
	end)

	it("has no mark when the active profile was deleted", function()
		s:delete("A")
		env.fake.bind("1", "JUMP")
		assert.equal(0, s:dirtyCount())
		assert.is_nil(s:dirtyDiff())
		assert.equal("errNoActive", s:saveToProfile().err)
	end)

	it("ignores and keeps bindings of commands this client does not declare", function()
		local p = s:getProfile("A")
		p.bindings.F6 = "OMEN_TOGGLE" -- e.g. an addon disabled on this character
		local step = s:requestApply("A")
		local done = s:confirmApply(step)
		assert.equal("rejected", done.report.issues[1].reason)
		assert.equal(0, s:dirtyCount())
		env.fake.bind("1", "JUMP")
		s:saveToProfile()
		assert.equal("OMEN_TOGGLE", s:getProfile("A").bindings.F6)
		assert.equal("JUMP", s:getProfile("A").bindings["1"])
	end)

	it("compares with the current content after another character edits the profile", function()
		s:getProfile("A").bindings["1"] = "JUMP"
		assert.equal(1, s:dirtyCount())
	end)
end)
