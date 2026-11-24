local Env = require("env")

describe("Service: shared bindings (US4)", function()
	local env, s
	before_each(function()
		env = Env.new({ bindings = { ["1"] = "ACTIONBUTTON1", TAB = "TARGETNEARESTENEMY", W = "MOVEFORWARD" } })
		s = env.service
		s:setCommonGroup("TARGETING", true)
	end)

	it("does not store shared bindings in profiles", function()
		s:saveCurrent("A")
		assert.same({ ["1"] = "ACTIONBUTTON1", W = "MOVEFORWARD" }, s:getProfile("A").bindings)
	end)

	it("keeps a shared binding across every apply (SC-011)", function()
		s:saveCurrent("A")
		env.fake.bind("1", "JUMP")
		s:saveCurrent("B")
		env.fake.bind("TAB", nil)
		env.fake.bind("F1", "TARGETNEARESTENEMY")
		for _, name in ipairs({ "A", "B", "A" }) do
			local step = s:requestApply(name)
			if step.step == "preview" then
				s:confirmApply(step)
			end
			assert.equal("TARGETNEARESTENEMY", env.fake.bindings().F1)
		end
	end)

	it("reports a conflict and keeps the shared binding", function()
		env.db.profiles.x = { name = "X", mode = "blizzard", bindings = { TAB = "JUMP" }, inactive = {}, origin = {} }
		local step = s:requestApply("X")
		local done = s:confirmApply(step)
		assert.equal("TARGETNEARESTENEMY", env.fake.bindings().TAB)
		local found = false
		for _, i in ipairs(done.report.issues) do
			if i.reason == "commonConflict" and i.key == "TAB" then
				found = true
			end
		end
		assert.is_true(found)
		assert.equal("JUMP", s:getProfile("X").bindings.TAB)
	end)

	it("skips shared bindings stored by older profiles but keeps them", function()
		env.db.profiles.old = { name = "Old", mode = "blizzard",
			bindings = { G = "TARGETNEARESTENEMY", ["1"] = "ACTIONBUTTON1" }, inactive = {}, origin = {} }
		s:confirmApply(s:requestApply("Old"))
		assert.is_nil(env.fake.bindings().G)
		assert.equal("TARGETNEARESTENEMY", env.fake.bindings().TAB)
		assert.equal("TARGETNEARESTENEMY", s:getProfile("Old").bindings.G)
	end)

	it("refuses bar groups and warns when all groups are shared", function()
		assert.equal("errGroupNotSelectable", s:setCommonGroup("ACTIONBAR", true).err)
		for _, key in ipairs({ "MOVEMENT", "CHAT", "MULTICASTFUNCTIONS", "CAMERA" }) do
			s:setCommonGroup(key, true)
		end
		assert.is_not_nil(env.noted("warnAllCommon"))
	end)
end)
