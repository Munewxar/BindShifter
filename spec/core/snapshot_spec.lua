local loader = require("loader")
local FakeWow = require("fake_wow")

describe("Snapshot", function()
	local ns
	before_each(function()
		ns = loader.loadCore()
	end)

	it("captures bindings of every type", function()
		local fake = FakeWow.new({ bindings = {
			["1"] = "ACTIONBUTTON1",
			["ALT-CTRL-SHIFT-Q"] = "SPELL Frost Nova",
			["BUTTON4"] = "MACRO Burst",
			["F5"] = "ITEM Hearthstone",
			["CTRL-MOUSEWHEELUP"] = "CLICK SomeAddonButton:LeftButton",
			["SHIFT--"] = "JUMP",
		} })
		local map = ns.Snapshot.capture(fake.api)
		assert.same(fake.bindings(), map)
	end)

	it("finds exotic keys through command lookups", function()
		local fake = FakeWow.new({ bindings = { ["OEM_EXOTIC"] = "JUMP" } })
		assert.equal("JUMP", ns.Snapshot.capture(fake.api)["OEM_EXOTIC"])
	end)

	it("finds Bartender4 click bindings while Bartender4 is disabled", function()
		local fake = FakeWow.new({ bt4 = false, bindings = { ["OEM_X"] = "CLICK BT4Button25:LeftButton" } })
		assert.equal("CLICK BT4Button25:LeftButton", ns.Snapshot.capture(fake.api)["OEM_X"])
	end)

	it("lists declared commands without headers", function()
		local set = ns.Snapshot.knownCommands(FakeWow.new().api)
		assert.is_true(set.JUMP)
		assert.is_nil(set.HEADER_MOVEMENT)
	end)
end)
