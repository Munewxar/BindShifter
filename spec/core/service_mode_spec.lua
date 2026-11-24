local Env = require("env")

describe("Service: mode switching (US5)", function()
	local env, s
	before_each(function()
		env = Env.new({ bt4 = true, bindings = { ["1"] = "ACTIONBUTTON1", Q = "CLICK BT4Button25:LeftButton" } })
		s = env.service
	end)

	it("stores the mode and the Bartender4 profile", function()
		env.fake.state.bt4.current = "Raid"
		s:saveCurrent("BT")
		local p = s:getProfile("BT")
		assert.equal("bt4", p.mode)
		assert.equal("Raid", p.bt4Profile)
		env.db.settings.rememberBT4Profile = false
		s:saveCurrent("BT2")
		assert.is_nil(s:getProfile("BT2").bt4Profile)
	end)

	it("asks for a mode choice when modes differ", function()
		env.db.profiles.blz = { name = "Blz", mode = "blizzard", bindings = { Q = "MULTIACTIONBAR3BUTTON1" },
			inactive = {}, origin = {} }
		local step = s:requestApply("Blz")
		assert.equal("needsModeChoice", step.step)
		assert.equal("blizzard", step.profileMode)
		assert.equal("bt4", step.currentMode)
		assert.equal("hiddenBar", step.unusable[1].reason)
	end)

	it("switches mode with one confirmation and applies after reload (SC-002)", function()
		env.db.profiles.blz = { name = "Blz", mode = "blizzard",
			bindings = { ["1"] = "ACTIONBUTTON1", Q = "MULTIACTIONBAR3BUTTON1" }, inactive = {}, origin = {} }
		local choice = s:requestApply("Blz")
		local step = s:confirmModeSwitch(choice)
		assert.equal("reloading", step.step)
		assert.equal(1, env.fake.state.reloads)
		assert.is_false(env.fake.state.addons.Bartender4.enabled)
		local pending = env.db.chars["Tester - Realm"].pending
		assert.same({ type = "applyAfterReload", profile = "blz", expectMode = "blizzard", at = 1000 }, pending)

		local fresh = env.reload()
		local done = fresh:onLoad()
		assert.equal("done", done.step)
		assert.same({ ["1"] = "ACTIONBUTTON1", Q = "MULTIACTIONBAR3BUTTON1" }, env.fake.bindings())
		assert.is_nil(env.db.chars["Tester - Realm"].pending)
		assert.equal("apply", fresh:listHistory()[1].op)
	end)

	it("cancels the pending apply when the mode did not change", function()
		env.db.profiles.blz = { name = "Blz", mode = "blizzard", bindings = {}, inactive = {}, origin = {} }
		s:confirmModeSwitch(s:requestApply("Blz"))
		env.fake.state.addons.Bartender4.enabled = true -- the toggle did not stick
		local fresh = env.reload()
		local result = fresh:onLoad()
		assert.equal("modeMismatch", result.err)
		assert.is_not_nil(env.noted("msgModeSwitchFailed"))
		assert.equal("CLICK BT4Button25:LeftButton", env.fake.bindings().Q)
	end)

	it("queues the pending apply when the reload lands in combat", function()
		env.db.profiles.blz = { name = "Blz", mode = "blizzard", bindings = {}, inactive = {}, origin = {} }
		s:confirmModeSwitch(s:requestApply("Blz"))
		local fresh = env.reload()
		env.fake.setCombat(true)
		assert.equal("queued", fresh:onLoad().step)
		env.fake.setCombat(false)
		fresh:onCombatEnd()
		assert.same({}, env.fake.bindings())
	end)

	it("never toggles addons or reloads in combat", function()
		env.db.profiles.blz = { name = "Blz", mode = "blizzard", bindings = {}, inactive = {}, origin = {} }
		local choice = s:requestApply("Blz")
		env.fake.setCombat(true)
		assert.equal("queued", s:confirmModeSwitch(choice).step)
		assert.equal(0, env.fake.state.reloads)
		env.fake.setCombat(false)
		assert.equal("reloading", s:onCombatEnd().step)
	end)

	it("applies without switching and warns about unusable bindings", function()
		env.db.profiles.blz = { name = "Blz", mode = "blizzard", bindings = { Q = "MULTIACTIONBAR3BUTTON1" },
			inactive = {}, origin = {} }
		local step = s:applyWithoutSwitch(s:requestApply("Blz"))
		assert.equal("preview", step.step)
		assert.same({ "warnModeMismatch" }, step.warnings)
		assert.equal("hiddenBar", step.issues[1].reason)
		s:confirmApply(step)
		assert.equal("MULTIACTIONBAR3BUTTON1", env.fake.bindings().Q)
	end)

	it("reports a missing Bartender4 installation", function()
		local e2 = Env.new({ bt4 = false, bt4Installed = false })
		e2.db.profiles.bt = { name = "BT", mode = "bt4", bindings = {}, inactive = {}, origin = {} }
		local choice = e2.service:requestApply("BT")
		assert.is_false(choice.bt4Installed)
		assert.equal("errBT4Missing", e2.service:confirmModeSwitch(choice).err)
		assert.is_nil(e2.db.chars["Tester - Realm"].pending)
	end)

	it("switches the Bartender4 profile before applying", function()
		env.db.profiles.bt = { name = "BT", mode = "bt4", bt4Profile = "Raid", bindings = { ["1"] = "ACTIONBUTTON1",
			Q = "CLICK BT4Button25:LeftButton" }, inactive = {}, origin = {} }
		local step = s:requestApply("BT")
		assert.equal("preview", step.step)
		assert.equal("Raid", step.bt4Switch)
		s:confirmApply(step)
		assert.equal("Raid", env.fake.state.bt4.current)
	end)

	it("warns when the stored Bartender4 profile is missing", function()
		env.db.profiles.bt = { name = "BT", mode = "bt4", bt4Profile = "Gone", bindings = { ["1"] = "JUMP" },
			inactive = {}, origin = {} }
		local done = s:confirmApply(s:requestApply("BT"))
		assert.equal("bt4ProfileMissing", done.report.issues[1].reason)
		assert.equal("JUMP", env.fake.bindings()["1"])
	end)

	it("edits the stored mode and Bartender4 profile", function()
		s:saveCurrent("BT")
		s:setProfileMode("BT", "blizzard")
		s:setProfileBT4("BT", "Raid")
		assert.equal("blizzard", s:getProfile("BT").mode)
		assert.equal("Raid", s:getProfile("BT").bt4Profile)
		s:setProfileBT4("BT", "")
		assert.is_nil(s:getProfile("BT").bt4Profile)
	end)
end)
