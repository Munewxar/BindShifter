local loader = require("loader")
local FakeWow = require("fake_wow")

describe("Groups", function()
	local ns, groups
	before_each(function()
		ns = loader.loadCore()
		groups = ns.Groups.build(FakeWow.new({ bt4 = true }).api)
	end)

	it("builds groups from binding headers", function()
		local keys = {}
		for _, g in ipairs(groups.list) do
			keys[#keys + 1] = g.key
		end
		assert.same({ "MOVEMENT", "CHAT", "ACTIONBAR", "MULTIACTIONBAR", "TARGETING",
			"MULTICASTFUNCTIONS", "CAMERA", "BARTENDER4" }, keys)
		assert.equal("Label MOVEMENT", groups.byKey.MOVEMENT.label)
	end)

	it("keeps BLANK spacers inside the current group", function()
		assert.equal("MULTICASTFUNCTIONS", groups.byCommand.MULTICASTSUMMONBUTTON2)
	end)

	it("marks bar groups as not selectable", function()
		assert.is_false(groups.byKey.ACTIONBAR.selectable)
		assert.is_false(groups.byKey.MULTIACTIONBAR.selectable)
		assert.is_false(groups.byKey.BARTENDER4.selectable)
		assert.is_true(groups.byKey.TARGETING.selectable)
	end)

	it("decides shared commands from the settings", function()
		local isCommon = ns.Groups.isCommonFn(groups, { TARGETING = true, ACTIONBAR = true })
		assert.is_true(isCommon("TARGETNEARESTENEMY"))
		assert.is_false(isCommon("JUMP"))
		assert.is_false(isCommon("ACTIONBUTTON1"))
		assert.is_false(isCommon("SPELL Frostbolt"))
	end)

	it("detects when every selectable group is shared", function()
		local all = {}
		for _, g in ipairs(groups.list) do
			all[g.key] = true
		end
		assert.is_true(ns.Groups.allSelected(groups, all))
		all.CAMERA = nil
		assert.is_false(ns.Groups.allSelected(groups, all))
	end)
end)
