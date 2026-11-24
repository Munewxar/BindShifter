local Env = require("env")

describe("Service: import and export (US7)", function()
	local env, s
	before_each(function()
		env = Env.new({ codec = true, bindings = { ["1"] = "ACTIONBUTTON1" } })
		s = env.service
		s:saveCurrent("Raid")
	end)

	it("exports and imports into another account", function()
		local text = s:exportProfile("Raid").text
		local other = Env.new({ codec = true })
		local preview = other.service:previewImport(text)
		assert.equal("importPreview", preview.step)
		assert.same({ name = "Raid", mode = "blizzard", count = 1, inactiveCount = 0 }, preview.summary)
		assert.is_false(preview.nameTaken)
		assert.equal("done", other.service:confirmImport(preview).step)
		assert.same(s:getProfile("Raid").bindings, other.service:getProfile("Raid").bindings)
		assert.equal("import", other.service:listHistory()[1].op)
	end)

	it("resolves name conflicts with a new name or a replace", function()
		local text = s:exportProfile("Raid").text
		local preview = s:previewImport(text)
		assert.is_true(preview.nameTaken)
		assert.equal("confirmImportName", s:confirmImport(preview).step)
		assert.equal("done", s:confirmImport(preview, { newName = "Raid 2" }).step)
		assert.equal("done", s:confirmImport(preview, { replace = true }).step)
		assert.equal("importReplace", s:listHistory()[1].op)
	end)

	it("changes nothing on a broken string", function()
		local before = env.ns.Util.deepCopy(env.db.profiles)
		assert.equal("errPrefix", s:previewImport("garbage").err)
		assert.same(before, env.db.profiles)
	end)
end)
