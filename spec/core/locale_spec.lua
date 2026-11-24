local loader = require("loader")

local function readAll(path)
	local f = assert(io.open(path, "r"))
	local text = f:read("*a")
	f:close()
	return text
end

-- Keys referenced by the code: L.key, notify("key"), err("key"), Chat.print(L, "key"), warnings.
local function usedKeys()
	local keys = {}
	for _, file in ipairs(loader.tocFiles()) do
		if not file:match("^Locales/") then
			local text = readAll("BindShifter/" .. file)
			for key in text:gmatch("%f[%w_]L%.([%a_][%w_]*)") do
				keys[key] = true
			end
			for key in text:gmatch('notify%("([%a_]+)"') do
				keys[key] = true
			end
			for key in text:gmatch('err%("([%a_]+)"') do
				keys[key] = true
			end
			for key in text:gmatch('Chat%.print%(L, "([%a_]+)"') do
				keys[key] = true
			end
			for key in text:gmatch('"(warn%u[%a]+)"') do
				keys[key] = true
			end
			for key in text:gmatch('reason = "([%a]+)"') do
				keys["reason_" .. key] = true
			end
			for key in text:gmatch('return "([%a]+)"') do
				if file:match("Validate") then
					keys["reason_" .. key] = true
				end
			end
			for key in text:gmatch('op = "([%a]+)"') do
				keys["op_" .. key] = true
			end
		end
	end
	for _, k in ipairs({ "mode_bt4", "mode_blizzard", "set_character", "set_account", "op_apply" }) do
		keys[k] = true
	end
	return keys
end

describe("Locales", function()
	local ns
	before_each(function()
		ns = loader.loadCore()
	end)

	it("ruRU has exactly the enUS keys (SC-009)", function()
		local en, ru = ns.Locales.enUS, ns.Locales.ruRU
		local missing, extra = {}, {}
		for k in pairs(en) do
			if ru[k] == nil then
				missing[#missing + 1] = k
			end
		end
		for k in pairs(ru) do
			if en[k] == nil then
				extra[#extra + 1] = k
			end
		end
		table.sort(missing)
		table.sort(extra)
		assert.same({}, missing)
		assert.same({}, extra)
	end)

	it("defines every key the code uses", function()
		local missing = {}
		for key in pairs(usedKeys()) do
			if ns.Locales.enUS[key] == nil then
				missing[#missing + 1] = key
			end
		end
		table.sort(missing)
		assert.same({}, missing)
	end)

	it("keeps format placeholders identical across locales", function()
		local en, ru = ns.Locales.enUS, ns.Locales.ruRU
		for k, v in pairs(en) do
			local a, b = {}, {}
			for p in v:gmatch("%%[ds]") do
				a[#a + 1] = p
			end
			for p in (ru[k] or ""):gmatch("%%[ds]") do
				b[#b + 1] = p
			end
			assert.same(a, b, k)
		end
	end)

	it("falls back to enUS and then to the key", function()
		local L = ns.Locale.build("ruRU")
		assert.equal("Применить", L.btnApply)
		local deDE = ns.Locale.build("deDE")
		assert.equal("Apply", deDE.btnApply)
		assert.equal("noSuchKey", deDE.noSuchKey)
	end)
end)
