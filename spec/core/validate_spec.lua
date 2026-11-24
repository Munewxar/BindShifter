local loader = require("loader")
local FakeWow = require("fake_wow")

describe("Validate", function()
	local ns, fake
	before_each(function()
		ns = loader.loadCore()
		fake = FakeWow.new({ spells = { Frostbolt = true }, macros = { Burst = true }, items = { Hearthstone = 1 },
			frames = { MyButton = true } })
	end)

	it("reports missing actions", function()
		local ctx = ns.Validate.newContext(fake.api)
		local issues = ns.Validate.issues(ctx, {
			["1"] = "SPELL Frostbolt",
			["2"] = "SPELL Fireball",
			["3"] = "MACRO Burst",
			["4"] = "MACRO Gone",
			["5"] = "ITEM Hearthstone",
			["6"] = "ITEM Rock",
			["7"] = "CLICK MyButton:LeftButton",
			["8"] = "CLICK Nope:LeftButton",
			["9"] = "CLICK BT4Button25:LeftButton",
			["0"] = "JUMP",
		})
		local reasons = {}
		for _, i in ipairs(issues) do
			reasons[i.key] = i.reason
		end
		assert.same({ ["2"] = "unknownSpell", ["4"] = "missingMacro", ["6"] = "missingItem",
			["8"] = "missingFrame", ["9"] = "missingFrame" }, reasons)
	end)

	it("reads the spellbook once per context", function()
		local calls = 0
		local real = fake.api.knownSpells
		fake.api.knownSpells = function()
			calls = calls + 1
			return real()
		end
		local ctx = ns.Validate.newContext(fake.api)
		ns.Validate.issues(ctx, { ["1"] = "SPELL A", ["2"] = "SPELL B" })
		assert.equal(1, calls)
	end)
end)
