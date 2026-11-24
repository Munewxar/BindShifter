local loader = require("loader")

describe("Migrations", function()
	local M
	before_each(function()
		M = loader.loadCore().Migrations
	end)

	it("creates a fresh v1 database with defaults", function()
		local db, status = M.run(nil, 1)
		assert.equal("fresh", status)
		assert.equal(1, db.schemaVersion)
		assert.same({ bindingSet = "character", accountSetAcknowledged = false,
			rememberBT4Profile = true, commonGroups = {} }, db.settings)
		assert.same({}, db.profiles)
		assert.same({}, db.chars)
	end)

	it("fills missing settings and profile fields", function()
		local db, status = M.run({ schemaVersion = 1, settings = { bindingSet = "account" },
			profiles = { raid = { name = "Raid", bindings = { ["1"] = "JUMP" } } } }, 1)
		assert.equal("ok", status)
		assert.equal("account", db.settings.bindingSet)
		assert.is_true(db.settings.rememberBT4Profile)
		assert.same({}, db.profiles.raid.inactive)
		assert.equal("blizzard", db.profiles.raid.mode)
	end)

	it("leaves newer data untouched in read-only mode", function()
		local original = { schemaVersion = 99, whatever = true }
		local db, status = M.run(original, 1)
		assert.equal("readOnly", status)
		assert.equal(original, db)
	end)

	it("quarantines unrecognised data without losing it", function()
		local original = { foo = "bar" }
		local db, status = M.run(original, 5)
		assert.equal("quarantined", status)
		assert.equal(original, db.quarantine.data)
		assert.equal(5, db.quarantine.at)
		assert.equal(1, db.schemaVersion)
	end)

	it("quarantines invalid schema versions instead of crashing", function()
		for _, v in ipairs({ 0, -1, 0.5 }) do
			local db, status = M.run({ schemaVersion = v, profiles = {} }, 1)
			assert.equal("quarantined", status)
			assert.equal(1, db.schemaVersion)
		end
	end)

	it("quarantines malformed profiles one by one", function()
		local db = M.run({ schemaVersion = 1, profiles = { bad = "x", good = { name = "Good" } } }, 1)
		assert.is_nil(db.profiles.bad)
		assert.equal("x", db.quarantine.data.profiles.bad)
		assert.is_not_nil(db.profiles.good)
	end)

	it("creates character state", function()
		local db = M.run(nil, 1)
		local c = M.ensureChar(db, "A - R")
		assert.same({ history = {}, nextHistoryId = 1 }, c)
		assert.equal(c, M.ensureChar(db, "A - R"))
	end)
end)
