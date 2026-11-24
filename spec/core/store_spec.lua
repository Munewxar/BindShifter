local loader = require("loader")

describe("Store", function()
	local ns, Store, db
	before_each(function()
		ns = loader.loadCore()
		Store = ns.Store
		db = ns.Migrations.run(nil, 1)
	end)

	it("validates names (trim, 1..50 characters)", function()
		assert.same({ false, "errNameEmpty" }, { Store.validateName("   ") })
		assert.same({ false, "errNameEmpty" }, { Store.validateName(nil) })
		assert.is_true(Store.validateName(string.rep("я", 50)))
		assert.same({ false, "errNameTooLong" }, { Store.validateName(string.rep("я", 51)) })
	end)

	it("treats names case-insensitively, including Cyrillic", function()
		assert.is_not_nil(Store.create(db, " Рейд ", { bindings = {} }, 1))
		assert.equal("Рейд", Store.get(db, "РЕЙД").name)
		assert.same({ nil, "errNameTaken" }, { Store.create(db, "рейд", {}, 2) })
	end)

	it("creates profiles with timestamps and empty service maps", function()
		local p = Store.create(db, "Raid", { mode = "bt4", bt4Profile = "Main", bindings = { ["1"] = "JUMP" } }, 10)
		assert.same({ name = "Raid", mode = "bt4", bt4Profile = "Main", bindings = { ["1"] = "JUMP" },
			inactive = {}, origin = {}, createdAt = 10, updatedAt = 10 }, p)
	end)

	it("overwrites content but keeps createdAt", function()
		Store.create(db, "Raid", { bindings = { ["1"] = "JUMP" } }, 10)
		local p = Store.overwrite(db, "raid", { bindings = { ["2"] = "JUMP" } }, 20)
		assert.equal(10, p.createdAt)
		assert.equal(20, p.updatedAt)
		assert.same({ ["2"] = "JUMP" }, p.bindings)
	end)

	it("renames and updates active profile references of every character", function()
		Store.create(db, "Raid", {}, 1)
		db.chars["A - R"] = { activeProfile = "raid", history = {} }
		db.chars["B - R"] = { activeProfile = "other", history = {} }
		Store.rename(db, "Raid", "Raid ICC", 2)
		assert.is_nil(Store.get(db, "Raid"))
		assert.equal("Raid ICC", Store.get(db, "raid icc").name)
		assert.equal("raid icc", db.chars["A - R"].activeProfile)
		assert.equal("other", db.chars["B - R"].activeProfile)
	end)

	it("refuses to rename onto an existing profile but allows a case change", function()
		Store.create(db, "A", {}, 1)
		Store.create(db, "B", {}, 1)
		assert.same({ nil, "errNameTaken" }, { Store.rename(db, "A", "b", 2) })
		assert.equal("a", (Store.rename(db, "A", "a", 2)).name)
	end)

	it("duplicates as an independent deep copy", function()
		Store.create(db, "A", { bindings = { ["1"] = "JUMP" } }, 1)
		local copy = Store.duplicate(db, "A", "B", 2)
		copy.bindings["1"] = "X"
		assert.equal("JUMP", Store.get(db, "A").bindings["1"])
	end)

	it("deletes and lists sorted", function()
		Store.create(db, "b", {}, 1)
		Store.create(db, "A", {}, 1)
		Store.create(db, "c", {}, 1)
		Store.delete(db, "C")
		local names = {}
		for _, p in ipairs(Store.list(db)) do
			names[#names + 1] = p.name
		end
		assert.same({ "A", "b" }, names)
		assert.same({ nil, "errNoProfile" }, { Store.delete(db, "zzz") })
	end)
end)
