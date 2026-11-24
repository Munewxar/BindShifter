-- WoW 3.3.5a implementation of contracts/wow-adapter.md. The only place where Core
-- reaches the game client.
local _, ns = ...

local WowApi = {}
ns.WowApi = WowApi

local SET_INDEX = { character = 2, account = 1 }
local SET_NAME = { [2] = "character", [1] = "account" }

function WowApi.new()
	local api = {}

	-- Bindings -----------------------------------------------------------------

	function api.getBindingAction(key)
		local action = GetBindingAction(key)
		if action == "" then
			return nil
		end
		return action
	end

	function api.listBindingCommands()
		local rows = {}
		for i = 1, GetNumBindings() do
			local command = GetBinding(i)
			if command then
				rows[#rows + 1] = { command = command, header = command:sub(1, 6) == "HEADER" }
			end
		end
		return rows
	end

	function api.getBindingKeys(command)
		return { GetBindingKey(command) }
	end

	-- Dispatch by command type (research.md R4). Returns false when the client refuses.
	-- Only SetBinding with a named command has a documented 3.3.5 return value (the
	-- Blizzard key binding UI relies on it). For clearing and typed commands the return
	-- value is not trusted; Apply's post-check verifies the result instead.
	function api.setBinding(key, command)
		if InCombatLockdown() then
			return false
		end
		if command == nil then
			SetBinding(key)
			return true
		end
		local spell = command:match("^SPELL (.+)$")
		local macro = command:match("^MACRO (.+)$")
		local item = command:match("^ITEM (.+)$")
		local frame, button = command:match("^CLICK ([^:]+):(.+)$")
		if spell then
			SetBindingSpell(key, spell)
		elseif macro then
			SetBindingMacro(key, macro)
		elseif item then
			SetBindingItem(key, item)
		elseif frame then
			SetBindingClick(key, frame, button)
		else
			return SetBinding(key, command) and true or false
		end
		return true
	end

	function api.saveBindings(set)
		if InCombatLockdown() then
			return
		end
		SaveBindings(SET_INDEX[set] or 2)
	end

	function api.currentBindingSet()
		return SET_NAME[GetCurrentBindingSet()] or "account"
	end

	-- Game state ---------------------------------------------------------------

	function api.inCombat()
		return InCombatLockdown() and true or false
	end

	function api.charKey()
		return (UnitName("player") or "?") .. " - " .. (GetRealmName() or "?")
	end

	function api.now()
		return time()
	end

	function api.clock()
		return debugprofilestop and debugprofilestop() or 0
	end

	function api.locale()
		return GetLocale()
	end

	-- Validation ---------------------------------------------------------------

	function api.knownSpells()
		local set = {}
		for tab = 1, GetNumSpellTabs() do
			local _, _, offset, count = GetSpellTabInfo(tab)
			for i = offset + 1, offset + count do
				local name = GetSpellName(i, BOOKTYPE_SPELL)
				if name then
					set[name] = true
				end
			end
		end
		-- Mounts and companions are cast by spell name too.
		for _, kind in ipairs({ "MOUNT", "CRITTER" }) do
			for i = 1, (GetNumCompanions(kind) or 0) do
				local _, _, spellId = GetCompanionInfo(kind, i)
				local name = spellId and GetSpellInfo(spellId)
				if name then
					set[name] = true
				end
			end
		end
		return set
	end

	function api.macroExists(name)
		local index = GetMacroIndexByName(name)
		return index ~= nil and index > 0
	end

	function api.itemCount(name)
		return GetItemCount(name) or 0
	end

	function api.frameExists(name)
		return _G[name] ~= nil
	end

	-- Addons and Bartender4 ----------------------------------------------------

	function api.isAddonLoaded(name)
		return IsAddOnLoaded(name) and true or false
	end

	function api.isAddonInstalled(name)
		local addonName, _, _, _, _, reason = GetAddOnInfo(name)
		return addonName ~= nil and reason ~= "MISSING"
	end

	function api.setAddonEnabled(name, enabled)
		if InCombatLockdown() or not api.isAddonInstalled(name) then
			return false
		end
		if enabled then
			EnableAddOn(name)
		else
			DisableAddOn(name)
		end
		return true
	end

	function api.reloadUI()
		if InCombatLockdown() then
			return
		end
		ReloadUI()
	end

	local function bt4db()
		local bt4 = _G.Bartender4
		return bt4 and bt4.db or nil
	end

	function api.bt4Profiles()
		local db = bt4db()
		if not db then
			return nil
		end
		local list = {}
		for _, name in ipairs((db:GetProfiles({}))) do
			list[#list + 1] = name
		end
		table.sort(list)
		return list
	end

	function api.bt4CurrentProfile()
		local db = bt4db()
		return db and db:GetCurrentProfile() or nil
	end

	function api.bt4SetProfile(name)
		local db = bt4db()
		if not db or InCombatLockdown() then
			return false
		end
		for _, existing in ipairs(api.bt4Profiles() or {}) do
			if existing == name then
				db:SetProfile(name)
				return true
			end
		end
		return false
	end

	function api.headerLabel(key)
		return _G["BINDING_HEADER_" .. key] or key
	end

	return api
end
