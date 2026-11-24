-- Addon lifecycle and event wiring. Loaded last (see BindShifter.toc).
local ADDON, ns = ...

local Addon = LibStub("AceAddon-3.0"):NewAddon(ADDON, "AceEvent-3.0", "AceConsole-3.0")
ns.Addon = Addon

-- ADDON_LOADED: read and migrate SavedVariables only (constitution, principle VI).
function Addon:OnInitialize()
	local db, status = ns.Migrations.run(BindShifterDB, time())
	self.dbStatus = status
	if status == "readOnly" then
		-- Data from a newer BindShifter: never write it back.
		self.db = ns.Migrations.fresh()
	else
		BindShifterDB = db
		self.db = db
	end
	self.L = ns.Locale.build(GetLocale())
	ns.Popups.register()
	ns.Slash.register(self)
end

-- PLAYER_LOGIN: the character name and realm are known.
function Addon:OnEnable()
	local L = self.L
	self.api = ns.WowApi.new()
	local codec = ns.Codec.new({
		serializer = LibStub("AceSerializer-3.0"),
		deflate = LibStub("LibDeflate"),
	})
	self.service = ns.Service.new({
		api = self.api,
		db = self.db,
		codec = codec,
		L = L,
		readOnly = self.dbStatus == "readOnly",
		notify = function(key, ...)
			ns.Chat.print(L, key, ...)
		end,
	})
	ns.ui = { service = self.service, L = L, addon = self }
	ns.Options.register()
	if self.dbStatus == "quarantined" then
		ns.Chat.print(L, "warnQuarantined")
	end
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("UPDATE_BINDINGS")
end

function Addon:PLAYER_ENTERING_WORLD()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	ns.Windows.handle(self.service:onLoad())
end

function Addon:PLAYER_REGEN_ENABLED()
	ns.Windows.handle(self.service:onCombatEnd())
end

function Addon:UPDATE_BINDINGS()
	if ns.Options.isVisible() and not self.service.applying then
		ns.Options.refresh()
	end
end
