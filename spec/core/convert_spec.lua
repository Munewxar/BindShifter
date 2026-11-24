local loader = require("loader")

describe("Convert", function()
	local ns
	before_each(function()
		ns = loader.loadCore()
	end)

	local bt4Profile = {
		mode = "bt4",
		bt4Profile = "Main",
		bindings = {
			["1"] = "CLICK BT4Button1:LeftButton",
			["2"] = "ACTIONBUTTON2",
			Q = "CLICK BT4Button25:LeftButton",
			E = "CLICK BT4Button13:LeftButton",
			R = "CLICK BT4Button100:LeftButton",
			P = "CLICK BT4PetButton1:LeftButton",
			F = "SPELL Frostbolt",
			W = "MOVEFORWARD",
		},
		inactive = {},
		origin = {},
	}

	it("converts Bartender4 to Blizzard by slot", function()
		local out, report = ns.Convert.convert(bt4Profile, "blizzard")
		assert.equal("blizzard", out.mode)
		assert.equal("Main", out.bt4Profile)
		assert.same({
			["1"] = "ACTIONBUTTON1",
			["2"] = "ACTIONBUTTON2",
			Q = "MULTIACTIONBAR3BUTTON1",
			P = "BONUSACTIONBUTTON1",
			F = "SPELL Frostbolt",
			W = "MOVEFORWARD",
		}, out.bindings)
		assert.same({ E = "CLICK BT4Button13:LeftButton", R = "CLICK BT4Button100:LeftButton" }, out.inactive)
		assert.same({ ["1"] = "CLICK BT4Button1:LeftButton", Q = "CLICK BT4Button25:LeftButton",
			P = "CLICK BT4PetButton1:LeftButton" }, out.origin)
		local untranslatable = 0
		for _, i in ipairs(report.issues) do
			if i.reason == "untranslatable" then
				untranslatable = untranslatable + 1
			end
		end
		assert.equal(2, untranslatable)
	end)

	it("round-trips binding for binding (SC-005)", function()
		local blizz = ns.Convert.convert(bt4Profile, "blizzard")
		local back = ns.Convert.convert(blizz, "bt4")
		assert.same(bt4Profile.bindings, back.bindings)
		assert.same({}, back.inactive)
		assert.same({}, back.origin)
	end)

	it("round-trips a Blizzard profile too", function()
		local blizz = { mode = "blizzard", bindings = { ["1"] = "ACTIONBUTTON1", Q = "MULTIACTIONBAR1BUTTON12" },
			inactive = {}, origin = {} }
		local bt = ns.Convert.convert(blizz, "bt4")
		assert.equal("CLICK BT4Button72:LeftButton", bt.bindings.Q)
		local back = ns.Convert.convert(bt, "blizzard")
		assert.same(blizz.bindings, back.bindings)
		assert.same({}, back.origin)
	end)

	it("does not use origin for keys changed after the conversion", function()
		local blizz = ns.Convert.convert(bt4Profile, "blizzard")
		blizz.bindings.Q = "MULTIACTIONBAR1BUTTON1"
		local back = ns.Convert.convert(blizz, "bt4")
		assert.equal("CLICK BT4Button61:LeftButton", back.bindings.Q)
	end)

	it("lets an active binding win over an inactive one on the same key", function()
		local blizz = ns.Convert.convert(bt4Profile, "blizzard")
		blizz.bindings.E = "JUMP"
		local back, report = ns.Convert.convert(blizz, "bt4")
		assert.equal("JUMP", back.bindings.E)
		assert.equal("CLICK BT4Button13:LeftButton", back.inactive.E)
		assert.equal("conversionConflict", report.issues[1].reason)
	end)

	it("does not modify the source profile", function()
		local copy = ns.Util.deepCopy(bt4Profile)
		ns.Convert.convert(bt4Profile, "blizzard")
		assert.same(copy, bt4Profile)
	end)
end)
