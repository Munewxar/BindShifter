local loader = require("loader")

describe("Keys", function()
	local Keys
	before_each(function()
		Keys = loader.loadCore().Keys
	end)

	it("normalizes modifier order", function()
		assert.equal("ALT-CTRL-SHIFT-F", Keys.normalize("SHIFT-CTRL-ALT-F"))
		assert.equal("ALT-SHIFT-1", Keys.normalize("shift-alt-1"))
		assert.equal("BUTTON4", Keys.normalize("BUTTON4"))
	end)

	it("keeps the minus key", function()
		assert.equal("-", Keys.normalize("-"))
		assert.equal("SHIFT--", Keys.normalize("SHIFT--"))
		assert.equal("CTRL-SHIFT--", Keys.normalize("SHIFT-CTRL--"))
	end)

	it("rejects empty keys", function()
		assert.is_nil(Keys.normalize(""))
		assert.is_nil(Keys.normalize(nil))
	end)

	it("enumerates every base key with 8 modifier prefixes", function()
		local all = Keys.allKeys()
		assert.equal(#Keys.BASE * 8, #all)
		local set = {}
		for _, k in ipairs(all) do
			set[k] = true
		end
		assert.is_true(set["ALT-CTRL-SHIFT-MOUSEWHEELUP"])
		assert.is_true(set["BUTTON31"])
		assert.is_true(set["SHIFT-NUMPAD5"])
		assert.is_true(set["CTRL-`"])
	end)
end)
