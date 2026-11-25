-- Executes the whole addon (Platform + UI) on stubbed WoW/Ace APIs to catch runtime errors
-- before the in-game check. Game behaviour itself is covered by the fake adapter.
local loader = require("loader")
local FakeWow = require("fake_wow")
local Stub = require("wow_ui_stub")

local function boot(env, fake)
	local ns = loader.load(loader.tocFiles())
	ns.WowApi.new = function()
		return fake.api
	end
	local addon = env.addon
	addon:OnInitialize()
	addon:OnEnable()
	addon:PLAYER_ENTERING_WORLD()
	return ns, addon
end

-- Calls every dynamic field of an AceConfig options tree.
local function walk(node, visit)
	visit(node)
	for _, child in pairs(node.args or {}) do
		walk(child, visit)
	end
end

describe("UI smoke", function()
	local env, ns, fake, addon, L

	local function slash(text)
		addon.commands.bsh(text)
	end

	local function opt(...)
		local node = env.options
		for _, key in ipairs({ ... }) do
			node = node.args[key]
		end
		return node
	end

	local function setup(locale, bindings)
		local serializer, deflate = loader.codecLibs()
		env = Stub.install()
		env.locale = locale
		env.realLibs["AceSerializer-3.0"] = serializer
		env.realLibs.LibDeflate = deflate
		_G.BindShifterDB = nil
		fake = FakeWow.new({ bt4 = true, bindings = bindings or {
			["1"] = "ACTIONBUTTON1",
			Q = "CLICK BT4Button25:LeftButton",
			TAB = "TARGETNEARESTENEMY",
		} })
		ns, addon = boot(env, fake)
		L = ns.ui.L
	end

	before_each(function()
		setup("ruRU")
	end)

	it("initializes saved variables, events, commands and the panel", function()
		assert.equal(1, _G.BindShifterDB.schemaVersion)
		assert.is_true(addon.events.PLAYER_REGEN_ENABLED)
		assert.is_true(addon.events.UPDATE_BINDINGS)
		assert.is_nil(addon.events.PLAYER_ENTERING_WORLD)
		assert.is_function(addon.commands.bindshifter)
		assert.is_table(env.options)
		assert.equal("Применить", L.btnApply)
	end)

	it("runs every slash command", function()
		slash("help")
		assert.is_true(env.chatContains(L.helpList))
		slash("list")
		assert.is_true(env.chatContains(L.noProfiles))
		slash("save")
		assert.is_true(env.chatContains(L.errNameEmpty))
		slash("save Рейд")
		assert.is_true(env.chatContains("Рейд"))
		slash("list")
		slash("apply рейд")
		assert.is_true(env.chatContains(L.msgNoChanges:format("Рейд")))
		fake.bind("1", "JUMP")
		slash("list")
		assert.is_true(env.chatContains(L.dirtyMark:format(1)))
		slash("apply Рейд")
		local preview = env.lastWindow()
		assert.equal(L.previewTitle:format("Рейд"), preview.title)
		env.click(L.btnApply)
		assert.is_true(preview.hidden)
		assert.equal("ACTIONBUTTON1", fake.bindings()["1"])
		slash("undo")
		-- The first apply switched the client from the account set: undo asks first.
		env.acceptPopup()
		assert.equal("JUMP", fake.bindings()["1"])
		slash("save Рейд")
		env.secondPopup()
		env.acceptPopup("Рейд 2")
		assert.is_not_nil(ns.ui.service:getProfile("Рейд 2"))
		slash("save Рейд")
		env.acceptPopup()
		assert.is_true(env.chatContains(L.msgSaved:format("Рейд", 3)))
		slash("diag")
		assert.is_true(env.chatContains("mode=bt4"))
		slash("whatever")
		assert.is_true(env.chatContains(L.errUnknownCommand:format("whatever")))
		slash("")
		assert.is_true(env.opened >= 1)
	end)

	it("evaluates every dynamic field of the options panel", function()
		slash("save Raid")
		local function visit(node)
			for _, field in ipairs({ "name", "desc", "values", "hidden", "disabled" }) do
				if type(node[field]) == "function" then
					node[field]()
				end
			end
			if type(node.get) == "function" then
				if node.type == "multiselect" then
					for key in pairs(node.values()) do
						node.get(nil, key)
					end
				else
					node.get()
				end
			end
		end
		walk(env.options, visit)
		fake.bind("1", "JUMP")
		env.hooks.OnShow()
		walk(env.options, visit)
		assert.is_false(opt("profiles", "showChanges").hidden())
	end)

	it("drives profile actions from the panel", function()
		opt("profiles", "saveAs").func()
		env.acceptPopup("Main")
		assert.is_not_nil(ns.ui.service:getProfile("Main"))

		opt("profiles", "profile").set(nil, "main")
		-- The list shows bare names; mode and Bartender4 profile are read-only text in the card.
		assert.equal("Main", opt("profiles", "profile").values().main)
		local card = opt("profiles", "card").name()
		assert.is_truthy(card:find(L.cardMode:format(L.mode_bt4), 1, true))
		assert.is_truthy(card:find(L.cardBT4Profile:format("Default"), 1, true))
		assert.is_nil(opt("profiles", "mode"))

		opt("profiles", "duplicate").func()
		env.acceptPopup("Copy")
		assert.is_not_nil(ns.ui.service:getProfile("Copy"))

		opt("profiles", "rename").func()
		env.acceptPopup("Copy 2")
		assert.is_not_nil(ns.ui.service:getProfile("Copy 2"))

		opt("profiles", "convert").func()
		env.acceptPopup()
		assert.is_not_nil(ns.ui.service:getProfile("Copy 2 (" .. L.mode_blizzard .. ")"))

		opt("profiles", "export").func()
		local exported
		for _, w in ipairs(env.widgets) do
			if w.kind == "MultiLineEditBox" then
				exported = w.text
			end
		end
		assert.equal("BSH1:", exported:sub(1, 5))

		opt("profiles", "delete").func()
		env.acceptPopup()
		opt("profiles", "undo").func()
		assert.equal(3, #ns.ui.service:listProfiles())
	end)

	it("handles the mode choice and applies without switching", function()
		slash("save Blz")
		ns.ui.service:setProfileMode("Blz", "blizzard")
		fake.bind("1", "JUMP")
		slash("apply Blz")
		assert.equal(L.modeChoiceTitle, env.lastWindow().title)
		env.click(L.btnApplyWithoutSwitch)
		assert.equal(L.previewTitle:format("Blz"), env.lastWindow().title)
		env.click(L.btnApply)
		assert.equal("ACTIONBUTTON1", fake.bindings()["1"])
	end)

	it("switches the mode through a reload and applies after loading", function()
		fake.bind("Q", "MULTIACTIONBAR3BUTTON1")
		slash("save Blz")
		ns.ui.service:setProfileMode("Blz", "blizzard")
		fake.bind("Q", "CLICK BT4Button25:LeftButton")
		slash("apply Blz")
		env.click(L.btnSwitchAndApply)
		assert.equal(1, fake.state.reloads)

		-- New UI session with the same SavedVariables and game state.
		fake.simulateReload()
		local db = _G.BindShifterDB
		local serializer, deflate = loader.codecLibs()
		env = Stub.install()
		env.locale = "ruRU"
		env.realLibs["AceSerializer-3.0"], env.realLibs.LibDeflate = serializer, deflate
		_G.BindShifterDB = db
		ns, addon = boot(env, fake)
		assert.equal("blizzard", ns.Mode.current(fake.api))
		assert.equal("MULTIACTIONBAR3BUTTON1", fake.bindings().Q)
	end)

	it("defers an apply in combat and runs it after combat", function()
		slash("save A")
		fake.bind("1", "JUMP")
		slash("apply A")
		fake.setCombat(true)
		env.click(L.btnApply)
		assert.is_true(env.chatContains(L.msgQueued))
		assert.equal("JUMP", fake.bindings()["1"])
		fake.setCombat(false)
		addon:PLAYER_REGEN_ENABLED()
		assert.equal("ACTIONBUTTON1", fake.bindings()["1"])
	end)

	it("imports through the import window", function()
		slash("save Raid")
		local text = ns.ui.service:exportProfile("Raid").text
		ns.Windows.showImport()
		local box
		for _, w in ipairs(env.widgets) do
			if w.kind == "MultiLineEditBox" then
				box = w
			end
		end
		box:SetText("garbage")
		env.click(L.btnCheck)
		assert.is_nil(env.findButton(L.btnImport))
		box:SetText(text)
		env.click(L.btnCheck)
		assert.is_false(box.button.shown)
		env.click(L.btnImport)
		-- The window closes before the name prompt and gives the pooled button back.
		assert.is_true(box.button.shown)
		env.acceptPopup("Raid 2")
		assert.is_not_nil(ns.ui.service:getProfile("Raid 2"))
	end)

	it("changes settings, shared groups and history from the panel", function()
		slash("save A")
		opt("common", "groups").set(nil, "TARGETING", true)
		assert.is_true(opt("common", "groups").get(nil, "TARGETING"))
		opt("common", "groups").set(nil, "ACTIONBAR", true)
		assert.is_true(env.chatContains(L.errGroupNotSelectable))

		opt("settings", "bindingSet").set(nil, "account")
		env.acceptPopup()
		assert.equal("account", ns.ui.service:settings().bindingSet)
		opt("settings", "rememberBT4").set(nil, false)
		assert.is_false(ns.ui.service:settings().rememberBT4Profile)

		local values = opt("history", "list").values()
		local id = next(values)
		opt("history", "list").set(nil, id)
		opt("history", "restore").func()
		env.acceptPopup()
		opt("history", "undo").func()
		assert.is_true(#env.popups <= 1)
	end)

	it("refreshes on binding changes only while the panel is shown", function()
		local before = env.notifyChanges
		addon:UPDATE_BINDINGS()
		assert.equal(before, env.notifyChanges)
		env.hooks.OnShow()
		local shown = env.notifyChanges
		addon:UPDATE_BINDINGS()
		assert.equal(shown + 1, env.notifyChanges)
		env.hooks.OnHide()
	end)

	it("passes the real AceConfigRegistry validation", function()
		local options = env.options
		loader.loadLibs({ "LibStub", "CallbackHandler-1.0", "AceConfigRegistry-3.0" })
		local registry = LibStub("AceConfigRegistry-3.0")
		assert.has_no.errors(function()
			registry:ValidateOptionsTable(options, "BindShifter")
		end)
	end)

	it("uses English on a non-Russian client", function()
		setup("enUS")
		assert.equal("Apply", L.btnApply)
		slash("help")
		assert.is_true(env.chatContains("/bsh list"))
	end)
end)
