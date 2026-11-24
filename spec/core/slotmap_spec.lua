local loader = require("loader")

describe("SlotMap", function()
	local SlotMap
	before_each(function()
		SlotMap = loader.loadCore().SlotMap
	end)

	local function bt4(n)
		return "CLICK BT4Button" .. n .. ":LeftButton"
	end

	it("maps bar 1 to ACTIONBUTTON", function()
		assert.same({ "ACTIONBUTTON1", "mapped" }, { SlotMap.toBlizzard(bt4(1)) })
		assert.same({ "ACTIONBUTTON12", "mapped" }, { SlotMap.toBlizzard(bt4(12)) })
	end)

	it("maps bars 3-6 to the multi-action bars", function()
		assert.same({ "MULTIACTIONBAR3BUTTON1", "mapped" }, { SlotMap.toBlizzard(bt4(25)) })
		assert.same({ "MULTIACTIONBAR4BUTTON12", "mapped" }, { SlotMap.toBlizzard(bt4(48)) })
		assert.same({ "MULTIACTIONBAR2BUTTON1", "mapped" }, { SlotMap.toBlizzard(bt4(49)) })
		assert.same({ "MULTIACTIONBAR1BUTTON12", "mapped" }, { SlotMap.toBlizzard(bt4(72)) })
	end)

	it("marks bars 2 and 7-10 as untranslatable", function()
		for _, n in ipairs({ 13, 24, 73, 120 }) do
			local res, status = SlotMap.toBlizzard(bt4(n))
			assert.is_nil(res)
			assert.equal("untranslatable", status)
		end
	end)

	it("maps pet and stance buttons", function()
		assert.same({ "BONUSACTIONBUTTON3", "mapped" }, { SlotMap.toBlizzard("CLICK BT4PetButton3:LeftButton") })
		assert.same({ "SHAPESHIFTBUTTON2", "mapped" }, { SlotMap.toBlizzard("CLICK BT4StanceButton2:LeftButton") })
	end)

	it("keeps non-bar and Blizzard commands unchanged when going to Blizzard", function()
		assert.same({ "SPELL Frostbolt", "same" }, { SlotMap.toBlizzard("SPELL Frostbolt") })
		assert.same({ "ACTIONBUTTON5", "same" }, { SlotMap.toBlizzard("ACTIONBUTTON5") })
	end)

	it("maps multi-action bars to Bartender4 buttons with the same slot", function()
		assert.same({ bt4(25), "mapped" }, { SlotMap.toBT4("MULTIACTIONBAR3BUTTON1") })
		assert.same({ bt4(61), "mapped" }, { SlotMap.toBT4("MULTIACTIONBAR1BUTTON1") })
		assert.same({ "ACTIONBUTTON1", "same" }, { SlotMap.toBT4("ACTIONBUTTON1") })
		assert.same({ "BONUSACTIONBUTTON1", "same" }, { SlotMap.toBT4("BONUSACTIONBUTTON1") })
	end)

	it("round-trips every multi-action button", function()
		for bar = 1, 4 do
			for i = 1, 12 do
				local cmd = "MULTIACTIONBAR" .. bar .. "BUTTON" .. i
				local b = SlotMap.toBT4(cmd)
				assert.equal(cmd, (SlotMap.toBlizzard(b)))
			end
		end
	end)

	it("detects bar commands and slots", function()
		assert.is_true(SlotMap.isBarCommand(bt4(1)))
		assert.is_true(SlotMap.isBarCommand("SHAPESHIFTBUTTON1"))
		assert.is_false(SlotMap.isBarCommand("CLICK BT4Button1:RightButton"))
		assert.is_false(SlotMap.isBarCommand("MULTIACTIONBAR5BUTTON1"))
		assert.equal(61, SlotMap.slotOf("MULTIACTIONBAR1BUTTON1"))
		assert.is_nil(SlotMap.slotOf("BONUSACTIONBUTTON1"))
	end)
end)
