local loader = require("loader")

describe("Slash.parse", function()
	local Slash
	before_each(function()
		Slash = loader.load({ "UI/Slash.lua" }).Slash
	end)

	it("returns an empty command for empty input", function()
		assert.same({ cmd = "", arg = "" }, Slash.parse(""))
		assert.same({ cmd = "", arg = "" }, Slash.parse("   "))
		assert.same({ cmd = "", arg = "" }, Slash.parse(nil))
	end)

	it("lowercases the sub-command and keeps the rest of the line", function()
		assert.same({ cmd = "apply", arg = "Raid ICC 25" }, Slash.parse("APPLY Raid ICC 25"))
		assert.same({ cmd = "save", arg = "Рейд" }, Slash.parse("  save   Рейд  "))
		assert.same({ cmd = "undo", arg = "" }, Slash.parse("undo"))
	end)

	it("does not list diag in help", function()
		for _, key in ipairs(Slash.HELP) do
			assert.is_nil(key:match("diag"))
		end
	end)
end)
