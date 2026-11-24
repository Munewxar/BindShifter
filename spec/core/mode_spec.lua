local loader = require("loader")
local FakeWow = require("fake_wow")

describe("Mode", function()
	local Mode
	before_each(function()
		Mode = loader.loadCore().Mode
	end)

	it("detects the current mode", function()
		assert.equal("bt4", Mode.current(FakeWow.new({ bt4 = true }).api))
		assert.equal("blizzard", Mode.current(FakeWow.new({ bt4 = false }).api))
		assert.is_false(Mode.bt4Installed(FakeWow.new({ bt4Installed = false }).api))
	end)

	it("lists bindings that will not work without switching", function()
		local profile = { mode = "bt4", bindings = {
			["1"] = "ACTIONBUTTON1",
			Q = "CLICK BT4Button25:LeftButton",
			P = "CLICK BT4PetButton1:LeftButton",
			F = "SPELL Frostbolt",
		} }
		local list = Mode.unusable(profile, "blizzard")
		assert.same({
			{ key = "P", command = "CLICK BT4PetButton1:LeftButton", reason = "missingFrame" },
			{ key = "Q", command = "CLICK BT4Button25:LeftButton", reason = "missingFrame" },
		}, list)
		local blizz = { mode = "blizzard", bindings = { Q = "MULTIACTIONBAR3BUTTON1", ["1"] = "ACTIONBUTTON1" } }
		assert.same({ { key = "Q", command = "MULTIACTIONBAR3BUTTON1", reason = "hiddenBar" } },
			Mode.unusable(blizz, "bt4"))
		assert.is_true(Mode.needsSwitch(blizz, "bt4"))
	end)
end)
