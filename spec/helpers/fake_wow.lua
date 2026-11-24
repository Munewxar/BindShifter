-- Fake WoW adapter implementing contracts/wow-adapter.md for busted tests.
local M = {}

local function copy(t)
	local c = {}
	for k, v in pairs(t or {}) do
		c[k] = v
	end
	return c
end

local function rows()
	local r = {}
	local function header(name)
		r[#r + 1] = { command = "HEADER_" .. name, header = true }
	end
	local function cmd(name)
		r[#r + 1] = { command = name, header = false }
	end
	header("MOVEMENT")
	for _, c in ipairs({ "MOVEFORWARD", "MOVEBACKWARD", "TURNLEFT", "TURNRIGHT", "JUMP" }) do
		cmd(c)
	end
	header("CHAT")
	cmd("OPENCHAT")
	cmd("REPLY")
	header("ACTIONBAR")
	for i = 1, 12 do
		cmd("ACTIONBUTTON" .. i)
	end
	for i = 1, 10 do
		cmd("BONUSACTIONBUTTON" .. i)
	end
	for i = 1, 10 do
		cmd("SHAPESHIFTBUTTON" .. i)
	end
	cmd("NEXTACTIONPAGE")
	header("MULTIACTIONBAR")
	for bar = 1, 4 do
		for i = 1, 12 do
			cmd("MULTIACTIONBAR" .. bar .. "BUTTON" .. i)
		end
	end
	header("TARGETING")
	cmd("TARGETNEARESTENEMY")
	cmd("TARGETSELF")
	header("MULTICASTFUNCTIONS")
	cmd("MULTICASTSUMMONBUTTON1")
	header("BLANK")
	cmd("MULTICASTSUMMONBUTTON2")
	header("CAMERA")
	cmd("CAMERAZOOMIN")
	cmd("CAMERAZOOMOUT")
	return r
end

local function bt4Rows()
	local r = { { command = "HEADER_BARTENDER4", header = true } }
	for i = 1, 120 do
		r[#r + 1] = { command = "CLICK BT4Button" .. i .. ":LeftButton", header = false }
	end
	for i = 1, 10 do
		r[#r + 1] = { command = "CLICK BT4PetButton" .. i .. ":LeftButton", header = false }
	end
	for i = 1, 10 do
		r[#r + 1] = { command = "CLICK BT4StanceButton" .. i .. ":LeftButton", header = false }
	end
	return r
end

function M.new(opts)
	opts = opts or {}
	local state = {
		work = copy(opts.bindings),
		sets = { account = copy(opts.bindings), character = nil },
		active = "account",
		combat = false,
		char = opts.char or "Tester - Realm",
		time = opts.time or 1000,
		locale = opts.locale or "enUS",
		addons = {
			Bartender4 = {
				installed = opts.bt4Installed ~= false,
				enabled = opts.bt4 == true,
				loaded = opts.bt4 == true,
			},
		},
		bt4 = { profiles = { "Default", "Raid" }, current = "Default" },
		spells = copy(opts.spells),
		macros = copy(opts.macros),
		items = copy(opts.items),
		frames = copy(opts.frames),
		reloads = 0,
		saves = {},
		protectedCalls = 0,
	}

	local function protected(name)
		state.protectedCalls = state.protectedCalls + 1
		if state.combat then
			error("protected call in combat: " .. name, 2)
		end
	end

	local function commandRows()
		local r = rows()
		if state.addons.Bartender4.loaded then
			for _, row in ipairs(bt4Rows()) do
				r[#r + 1] = row
			end
		end
		return r
	end

	local function knownCommand(cmd)
		for _, row in ipairs(commandRows()) do
			if row.command == cmd then
				return true
			end
		end
		return false
	end

	local api = {}

	function api.getBindingAction(key)
		return state.work[key]
	end

	function api.listBindingCommands()
		return commandRows()
	end

	function api.getBindingKeys(cmd)
		local keys = {}
		for key, c in pairs(state.work) do
			if c == cmd then
				keys[#keys + 1] = key
			end
		end
		table.sort(keys)
		return keys
	end

	function api.setBinding(key, cmd)
		protected("setBinding")
		if cmd == nil then
			state.work[key] = nil
			return true
		end
		local isTyped = cmd:match("^SPELL ") or cmd:match("^MACRO ") or cmd:match("^ITEM ") or cmd:match("^CLICK ")
		if not isTyped and not knownCommand(cmd) then
			return false
		end
		state.work[key] = cmd
		return true
	end

	function api.saveBindings(set)
		protected("saveBindings")
		state.saves[#state.saves + 1] = set
		if set == "account" then
			state.sets.account = copy(state.work)
			state.sets.character = nil
		else
			state.sets.character = copy(state.work)
		end
		state.active = set
	end

	function api.currentBindingSet()
		return state.active
	end

	function api.inCombat()
		return state.combat
	end

	function api.charKey()
		return state.char
	end

	function api.now()
		return state.time
	end

	function api.locale()
		return state.locale
	end

	function api.knownSpells()
		return copy(state.spells)
	end

	function api.macroExists(name)
		return state.macros[name] == true
	end

	function api.itemCount(name)
		return state.items[name] or 0
	end

	function api.frameExists(name)
		if state.frames[name] then
			return true
		end
		if state.addons.Bartender4.loaded and name:match("^BT4") then
			return true
		end
		return false
	end

	function api.isAddonLoaded(name)
		local a = state.addons[name]
		return a ~= nil and a.loaded == true
	end

	function api.isAddonInstalled(name)
		local a = state.addons[name]
		return a ~= nil and a.installed == true
	end

	function api.setAddonEnabled(name, enabled)
		protected("setAddonEnabled")
		local a = state.addons[name]
		if not a or not a.installed then
			return false
		end
		a.enabled = enabled
		return true
	end

	function api.reloadUI()
		protected("reloadUI")
		state.reloads = state.reloads + 1
	end

	function api.bt4Profiles()
		if not state.addons.Bartender4.loaded then
			return nil
		end
		return copy(state.bt4.profiles)
	end

	function api.bt4CurrentProfile()
		if not state.addons.Bartender4.loaded then
			return nil
		end
		return state.bt4.current
	end

	function api.bt4SetProfile(name)
		protected("bt4SetProfile")
		if not state.addons.Bartender4.loaded then
			return false
		end
		for _, p in ipairs(state.bt4.profiles) do
			if p == name then
				state.bt4.current = name
				return true
			end
		end
		return false
	end

	function api.headerLabel(key)
		return "Label " .. key
	end

	-- Test helpers (not part of the contract) ------------------------------
	local fake = { api = api, state = state }

	function fake.setCombat(on)
		state.combat = on
	end

	-- Emulates a UI reload: addon load state follows the enabled flag and the
	-- in-memory bindings are reloaded from the active set.
	function fake.simulateReload()
		for _, a in pairs(state.addons) do
			a.loaded = a.installed and a.enabled
		end
		state.work = copy(state.sets[state.active] or state.sets.account)
	end

	function fake.bind(key, cmd)
		state.work[key] = cmd
	end

	function fake.bindings()
		return copy(state.work)
	end

	return fake
end

return M
