-- Exercises Platform/WowApi.lua against stubbed 3.3.5 globals (signatures from FrameXML).
local loader = require("loader")

describe("WowApi (3.3.5 adapter)", function()
	local api, G, calls

	before_each(function()
		G = _G
		calls = {}
		local bindings = { ["1"] = "ACTIONBUTTON1", ["SHIFT-1"] = "ACTIONBUTTON1" }
		local rows = { "HEADER_MOVEMENT", "JUMP", "ACTIONBUTTON1" }
		G.GetBindingAction = function(key)
			return bindings[key] or ""
		end
		G.GetNumBindings = function()
			return #rows
		end
		G.GetBinding = function(i)
			return rows[i]
		end
		G.GetBindingKey = function(cmd)
			local keys = {}
			for k, c in pairs(bindings) do
				if c == cmd then
					keys[#keys + 1] = k
				end
			end
			table.sort(keys)
			return unpack(keys)
		end
		G.SetBinding = function(key, cmd)
			calls[#calls + 1] = { "SetBinding", key, cmd }
			if cmd == "NOSUCH" then
				return nil
			end
			bindings[key] = cmd
			return 1
		end
		G.SetBindingSpell = function(key, name)
			calls[#calls + 1] = { "SetBindingSpell", key, name }
		end
		G.SetBindingMacro = function(key, name)
			calls[#calls + 1] = { "SetBindingMacro", key, name }
		end
		G.SetBindingItem = function(key, name)
			calls[#calls + 1] = { "SetBindingItem", key, name }
		end
		G.SetBindingClick = function(key, frame, button)
			calls[#calls + 1] = { "SetBindingClick", key, frame, button }
		end
		G.SaveBindings = function(which)
			calls[#calls + 1] = { "SaveBindings", which }
		end
		G.GetCurrentBindingSet = function()
			return 2
		end
		G.InCombatLockdown = function()
			return G.__combat
		end
		G.UnitName = function()
			return "Tester"
		end
		G.GetRealmName = function()
			return "Icecrown"
		end
		G.time = os.time
		G.GetLocale = function()
			return "ruRU"
		end
		G.BOOKTYPE_SPELL = "spell"
		G.GetNumSpellTabs = function()
			return 1
		end
		G.GetSpellTabInfo = function()
			return "General", "icon", 0, 2
		end
		G.GetSpellName = function(i)
			return ({ "Frostbolt", "Blink" })[i], "Rank 1"
		end
		G.GetNumCompanions = function(kind)
			return kind == "MOUNT" and 1 or 0
		end
		G.GetCompanionInfo = function()
			return 1, "Horse", 458, "icon", nil
		end
		G.GetSpellInfo = function(id)
			return id == 458 and "Brown Horse" or nil
		end
		G.GetMacroIndexByName = function(name)
			return name == "Burst" and 3 or 0
		end
		G.GetItemCount = function(name)
			return name == "Hearthstone" and 1 or 0
		end
		G.IsAddOnLoaded = function(name)
			return name == "Bartender4" and 1 or nil
		end
		G.GetAddOnInfo = function(name)
			if name == "Bartender4" then
				return "Bartender4", "Bartender4", "", 1, 1, nil, nil
			end
			return name, nil, nil, nil, nil, "MISSING", nil
		end
		G.EnableAddOn = function(name)
			calls[#calls + 1] = { "EnableAddOn", name }
		end
		G.DisableAddOn = function(name)
			calls[#calls + 1] = { "DisableAddOn", name }
		end
		G.ReloadUI = function()
			calls[#calls + 1] = { "ReloadUI" }
		end
		local current = "Default"
		G.Bartender4 = { db = {
			GetProfiles = function(_, t)
				t[1], t[2] = "Raid", "Default"
				return t, 2
			end,
			GetCurrentProfile = function()
				return current
			end,
			SetProfile = function(_, name)
				current = name
			end,
		} }
		G.BINDING_HEADER_MOVEMENT = "Перемещение"
		G.__combat = nil
		api = loader.load({ "Platform/WowApi.lua" }).WowApi.new()
	end)

	after_each(function()
		G.Bartender4 = nil
	end)

	it("reads bindings", function()
		assert.equal("ACTIONBUTTON1", api.getBindingAction("1"))
		assert.is_nil(api.getBindingAction("2"))
		assert.same({ "1", "SHIFT-1" }, api.getBindingKeys("ACTIONBUTTON1"))
		local rows = api.listBindingCommands()
		assert.same({ command = "HEADER_MOVEMENT", header = true }, rows[1])
		assert.same({ command = "JUMP", header = false }, rows[2])
	end)

	it("dispatches binding calls by command type", function()
		assert.is_true(api.setBinding("Q", "SPELL Frost Nova"))
		assert.is_true(api.setBinding("W", "MACRO Burst"))
		assert.is_true(api.setBinding("E", "ITEM Hearthstone"))
		assert.is_true(api.setBinding("R", "CLICK BT4Button25:LeftButton"))
		assert.is_true(api.setBinding("T", "JUMP"))
		assert.is_false(api.setBinding("Y", "NOSUCH"))
		assert.is_true(api.setBinding("T", nil))
		assert.same({ "SetBindingSpell", "Q", "Frost Nova" }, calls[1])
		assert.same({ "SetBindingMacro", "W", "Burst" }, calls[2])
		assert.same({ "SetBindingItem", "E", "Hearthstone" }, calls[3])
		assert.same({ "SetBindingClick", "R", "BT4Button25", "LeftButton" }, calls[4])
		assert.same({ "SetBinding", "T", "JUMP" }, calls[5])
		assert.same({ "SetBinding", "T", nil }, calls[7])
	end)

	it("maps binding sets", function()
		api.saveBindings("character")
		api.saveBindings("account")
		assert.same({ "SaveBindings", 2 }, calls[1])
		assert.same({ "SaveBindings", 1 }, calls[2])
		assert.equal("character", api.currentBindingSet())
	end)

	it("refuses protected calls in combat", function()
		G.__combat = 1
		assert.is_true(api.inCombat())
		assert.is_false(api.setBinding("1", "JUMP"))
		api.saveBindings("character")
		api.reloadUI()
		assert.is_false(api.setAddonEnabled("Bartender4", false))
		assert.is_false(api.bt4SetProfile("Raid"))
		assert.same({}, calls)
	end)

	it("reports game state and validation data", function()
		assert.equal("Tester - Icecrown", api.charKey())
		assert.equal("ruRU", api.locale())
		assert.is_number(api.now())
		assert.same({ Frostbolt = true, Blink = true, ["Brown Horse"] = true }, api.knownSpells())
		assert.is_true(api.macroExists("Burst"))
		assert.is_false(api.macroExists("Nope"))
		assert.equal(1, api.itemCount("Hearthstone"))
		assert.is_true(api.frameExists("Bartender4"))
		assert.is_false(api.frameExists("NoSuchFrame"))
		assert.equal("Перемещение", api.headerLabel("MOVEMENT"))
		assert.equal("CHAT", api.headerLabel("CHAT"))
	end)

	it("manages addons and Bartender4 profiles", function()
		assert.is_true(api.isAddonLoaded("Bartender4"))
		assert.is_true(api.isAddonInstalled("Bartender4"))
		assert.is_false(api.isAddonInstalled("Nope"))
		assert.is_true(api.setAddonEnabled("Bartender4", false))
		assert.is_false(api.setAddonEnabled("Nope", true))
		api.reloadUI()
		assert.same({ "DisableAddOn", "Bartender4" }, calls[1])
		assert.same({ "ReloadUI" }, calls[2])
		assert.same({ "Default", "Raid" }, api.bt4Profiles())
		assert.equal("Default", api.bt4CurrentProfile())
		assert.is_true(api.bt4SetProfile("Raid"))
		assert.equal("Raid", api.bt4CurrentProfile())
		assert.is_false(api.bt4SetProfile("Missing"))
	end)
end)
