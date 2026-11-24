local loader = require("loader")

describe("Commands", function()
	local Commands
	before_each(function()
		Commands = loader.loadCore().Commands
	end)

	it("classifies commands", function()
		assert.equal("bar", Commands.classify("ACTIONBUTTON1"))
		assert.equal("bar", Commands.classify("CLICK BT4Button25:LeftButton"))
		assert.equal("spell", Commands.classify("SPELL Frost Nova"))
		assert.equal("macro", Commands.classify("MACRO Burst"))
		assert.equal("item", Commands.classify("ITEM Hearthstone"))
		assert.equal("click", Commands.classify("CLICK MyFrame:LeftButton"))
		assert.equal("named", Commands.classify("TARGETNEARESTENEMY"))
	end)

	it("parses typed commands", function()
		assert.same({ kind = "spell", name = "Frost Nova" }, Commands.parse("SPELL Frost Nova"))
		assert.same({ kind = "click", frame = "MyFrame", button = "RightButton" }, Commands.parse("CLICK MyFrame:RightButton"))
		local bar = Commands.parse("CLICK BT4Button25:LeftButton")
		assert.equal("BT4Button25", bar.frame)
		assert.equal(25, bar.bar.slot)
	end)

	it("normalizes client command strings", function()
		assert.equal("CLICK MyFrame:LeftButton", Commands.normalize("CLICK MyFrame"))
		assert.equal("JUMP", Commands.normalize(" JUMP "))
		assert.is_nil(Commands.normalize(""))
		assert.is_nil(Commands.normalize(nil))
	end)
end)
