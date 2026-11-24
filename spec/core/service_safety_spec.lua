local Env = require("env")

describe("Service: backups and undo (US2)", function()
	local env, s
	local original = { ["1"] = "ACTIONBUTTON1", ["2"] = "ACTIONBUTTON2", TAB = "TARGETNEARESTENEMY" }

	before_each(function()
		env = Env.new({ bindings = original })
		s = env.service
	end)

	local function snapshot()
		return { bindings = env.fake.bindings(), profiles = env.ns.Util.deepCopy(env.db.profiles),
			active = env.db.chars["Tester - Realm"].activeProfile }
	end

	it("undoes an apply exactly (SC-004)", function()
		s:saveCurrent("A")
		env.fake.bind("1", "JUMP")
		env.fake.bind("9", "SPELL X")
		s:saveCurrent("B")
		s:confirmApply(s:requestApply("A"))
		local before = snapshot()
		env.tick()
		s:confirmApply(s:requestApply("B"))
		assert.equal("done", s:undo().step)
		assert.same(before, snapshot())
	end)

	it("creates a backup before every mutating operation and undoes each", function()
		local ops = {
			function() s:saveCurrent("A") end,
			function() s:saveCurrent("A", true) end,
			function() s:rename("A", "B") end,
			function() s:duplicate("B", "C") end,
			function() s:setProfileMode("C", "bt4") end,
			function() s:delete("C") end,
			function() s:setBindingSet("account", true) end,
		}
		for _, op in ipairs(ops) do
			local before = snapshot()
			local settings = env.ns.Util.deepCopy(env.db.settings)
			local count = #env.db.chars["Tester - Realm"].history
			op()
			assert.equal(count + 1, #env.db.chars["Tester - Realm"].history)
			s:undo()
			assert.same(before, snapshot())
			assert.same(settings, env.db.settings)
			op()
		end
	end)

	it("reverts rename references for every character", function()
		s:saveCurrent("A")
		env.db.chars["Other - Realm"] = { activeProfile = "a", history = {} }
		s:rename("A", "B")
		assert.equal("b", env.db.chars["Other - Realm"].activeProfile)
		s:undo()
		assert.equal("a", env.db.chars["Other - Realm"].activeProfile)
		assert.is_not_nil(s:getProfile("A"))
		assert.is_nil(s:getProfile("B"))
	end)

	it("undoes two operations in a row", function()
		s:saveCurrent("A")
		s:saveCurrent("B")
		s:undo()
		s:undo()
		assert.same({}, env.db.profiles)
		assert.equal("errNothingToUndo", s:undo().err)
	end)

	it("restores any backup and makes the restore undoable", function()
		s:saveCurrent("A")
		env.fake.bind("1", "JUMP")
		s:saveCurrent("B")
		s:confirmApply(s:requestApply("A"))
		local applyEntry = s:listHistory()[1]
		assert.equal("apply", applyEntry.op)
		env.fake.bind("5", "JUMP")
		-- This apply ran while the client was on the account set: restoring it asks first.
		assert.equal("confirmRestoreAccount", s:restore(applyEntry.id).step)
		assert.equal("done", s:restore(applyEntry.id, true).step)
		assert.equal("JUMP", env.fake.bindings()["1"])
		assert.is_nil(env.fake.bindings()["5"])
		assert.equal("restore", s:listHistory()[1].op)
		s:undo()
		assert.equal("JUMP", env.fake.bindings()["5"])
	end)

	it("warns about an empty profile in the preview", function()
		env.fake.state.work = {}
		s:saveCurrent("Empty")
		env.fake.bind("1", "JUMP")
		local step = s:requestApply("Empty")
		assert.same({ "warnEmptyProfile" }, step.warnings)
	end)

	it("asks before switching to the account set and then saves there", function()
		assert.equal("confirmAccountSet", s:setBindingSet("account").step)
		assert.equal("character", env.db.settings.bindingSet)
		s:setBindingSet("account", true)
		assert.is_true(env.db.settings.accountSetAcknowledged)
		s:saveCurrent("A")
		env.fake.bind("1", "JUMP")
		s:confirmApply(s:requestApply("A"))
		assert.same({ "account" }, env.fake.state.saves)
		assert.is_nil(env.fake.state.sets.character)
	end)

	it("applies to the character set by default", function()
		s:saveCurrent("A")
		env.fake.bind("1", "JUMP")
		s:confirmApply(s:requestApply("A"))
		assert.same({ "character", "character" }, env.fake.state.saves)
		-- The account set keeps its original content; only the character set changed.
		assert.equal("ACTIONBUTTON1", env.fake.state.sets.account["1"])
		assert.equal("ACTIONBUTTON1", env.fake.state.sets.character["1"])
	end)

	it("undoes the first apply back into the account set after confirmation (SC-004)", function()
		-- The client starts on the account set; the addon applies to the character set.
		s:saveCurrent("A")
		env.fake.bind("1", "JUMP")
		s:saveCurrent("B")
		env.fake.bind("1", "ACTIONBUTTON1")
		local accountBefore = env.ns.Util.deepCopy(env.fake.state.sets.account)
		s:confirmApply(s:requestApply("B"))
		assert.equal("character", env.fake.state.active)
		assert.equal("confirmRestoreAccount", s:undo().step)
		assert.equal("done", s:undo(true).step)
		assert.equal("account", env.fake.state.active)
		assert.is_nil(env.fake.state.sets.character)
		assert.same(accountBefore, env.fake.state.sets.account)
		assert.equal("ACTIONBUTTON1", env.fake.bindings()["1"])
	end)

	it("undoing a binding-set change keeps shared groups and other settings", function()
		s:setBindingSet("account", true)
		s:setCommonGroup("MOVEMENT", true)
		s:setRememberBT4(false)
		s:undo()
		assert.equal("character", env.db.settings.bindingSet)
		assert.is_true(env.db.settings.commonGroups.MOVEMENT)
		assert.is_false(env.db.settings.rememberBT4Profile)
	end)

	it("reports bindings refused while undoing", function()
		s:saveCurrent("A")
		env.db.profiles.x = { name = "X", mode = "blizzard", bindings = { ["1"] = "JUMP" }, inactive = {}, origin = {} }
		env.fake.state.active = "character"
		s:confirmApply(s:requestApply("X"))
		local real = env.fake.api.setBinding
		env.fake.api.setBinding = function(key, cmd)
			if cmd == "ACTIONBUTTON1" then
				return false
			end
			return real(key, cmd)
		end
		local step = s:undo()
		assert.equal("done", step.step)
		assert.equal("rejected", step.report.issues[1].reason)
	end)

	it("a queued undo reverts the entry chosen in combat, not a newer one", function()
		env.fake.state.active = "character"
		s:saveCurrent("A")
		env.fake.bind("1", "JUMP")
		s:saveCurrent("B")
		s:confirmApply(s:requestApply("A"))
		env.fake.setCombat(true)
		assert.equal("queued", s:undo().step)
		s:saveCurrent("C") -- recorded during combat, needs no game calls
		env.fake.setCombat(false)
		s:onCombatEnd()
		assert.equal("JUMP", env.fake.bindings()["1"])
		assert.is_not_nil(s:getProfile("C"))
	end)

	it("refuses mutations in read-only mode", function()
		local ro = Env.new({ readOnly = true })
		assert.equal("errReadOnly", ro.service:saveCurrent("A").err)
		assert.equal("errReadOnly", ro.service:undo().err)
	end)
end)
