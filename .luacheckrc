-- luacheck configuration. Core must not touch WoW globals (constitution, principle IV).
std = "lua51"
max_line_length = 160
exclude_files = { "BindShifter/Libs/**", ".lua/**" }

local WOW_API = {
	-- bindings
	"GetBindingAction", "GetNumBindings", "GetBinding", "GetBindingKey", "GetBindingText",
	"SetBinding", "SetBindingSpell", "SetBindingMacro", "SetBindingItem", "SetBindingClick",
	"SaveBindings", "GetCurrentBindingSet",
	-- game state
	"InCombatLockdown", "UnitName", "GetRealmName", "GetLocale", "time", "date", "debugprofilestop",
	-- spells, macros, items
	"GetNumSpellTabs", "GetSpellTabInfo", "GetSpellName", "GetSpellInfo", "BOOKTYPE_SPELL",
	"GetNumCompanions", "GetCompanionInfo", "GetMacroIndexByName", "GetItemCount",
	-- addons
	"IsAddOnLoaded", "GetAddOnInfo", "EnableAddOn", "DisableAddOn", "ReloadUI", "LibStub",
	-- UI
	"DEFAULT_CHAT_FRAME", "StaticPopup_Show", "InterfaceOptionsFrame_OpenToCategory",
	"YES", "NO", "ACCEPT", "CANCEL", "_G",
}

files["BindShifter/Core/**"] = {}
files["BindShifter/Locales/**"] = { max_line_length = false }
files["BindShifter/Platform/**"] = { read_globals = WOW_API, globals = { "BindShifterDB" } }
files["BindShifter/UI/**"] = { read_globals = WOW_API, globals = { "StaticPopupDialogs" } }
files["spec/**"] = {
	std = "+busted",
	globals = {
		"LibStub", "strmatch", "strfind", "strsub", "strlen", "strbyte", "strchar", "strrep",
		"format", "gsub", "tinsert", "tremove", "wipe",
	},
}
-- The UI stub installs WoW globals on purpose.
files["spec/helpers/wow_ui_stub.lua"] = {
	globals = {
		"LibStub", "DEFAULT_CHAT_FRAME", "GetBindingText", "date", "time", "GetLocale",
		"YES", "NO", "ACCEPT", "CANCEL", "StaticPopupDialogs", "StaticPopup_Show",
		"InterfaceOptionsFrame_OpenToCategory",
	},
}
