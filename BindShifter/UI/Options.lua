-- Interface Options panel (AceConfig, contracts/ui-panel.md, FR-070).
local _, ns = ...

local Options = {}
ns.Options = Options

local APP = "BindShifter"

local selected -- normalized key of the selected profile
local selectedHistory
local panelFrame
local visible = false
local cache = {}

local function ui()
	return ns.ui.service, ns.ui.L
end

local function handle(step)
	ns.Windows.handle(step)
end

local function status()
	if not cache.status then
		cache.status = ns.ui.service:status()
	end
	return cache.status
end

function Options.refresh()
	cache = {}
	local registry = LibStub("AceConfigRegistry-3.0", true)
	if registry then
		registry:NotifyChange(APP)
	end
end

function Options.isVisible()
	return visible
end

local function selectedProfile()
	local service = ui()
	if selected then
		local p = service:getProfile(selected)
		if p then
			return p
		end
	end
	local active = service:activeProfile()
	if active then
		selected = ns.Store.normalize(active.name)
		return active
	end
	local list = service:listProfiles()
	if list[1] then
		selected = list[1].key
		return service:getProfile(selected)
	end
	selected = nil
	return nil
end

local function noProfile()
	return selectedProfile() == nil
end

local function selectAfter(step)
	if step and step.step == "done" and step.name then
		selected = ns.Store.normalize(step.name)
	end
	handle(step)
end

local function buildOptions()
	local service, L = ui()
	local Format = ns.Format

	local function dirtyHidden()
		return status().dirty == 0
	end

	return {
		type = "group",
		name = "BindShifter",
		childGroups = "tab",
		args = {
			profiles = {
				type = "group",
				name = L.tabProfiles,
				order = 1,
				args = {
					status = {
						type = "description",
						order = 1,
						fontSize = "medium",
						name = function()
							local s = status()
							local text = L.statusLine:format(Format.mode(L, s.mode), s.active or L.none, L["set_" .. s.bindingSet])
							if s.dirty > 0 then
								text = text .. "  |cffffd100" .. L.dirtyMark:format(s.dirty) .. "|r"
							end
							if s.readOnly then
								text = text .. "\n|cffff6060" .. L.warnReadOnly .. "|r"
							end
							return text
						end,
					},
					showChanges = {
						type = "execute",
						order = 2,
						name = L.btnShowChanges,
						hidden = dirtyHidden,
						func = function()
							local diff = service:dirtyDiff()
							if diff then
								ns.Windows.showPreview({ name = status().active, diff = diff }, true)
							end
						end,
					},
					saveToProfile = {
						type = "execute",
						order = 3,
						name = L.btnSaveToProfile,
						hidden = dirtyHidden,
						func = function()
							handle(service:saveToProfile())
						end,
					},
					revert = {
						type = "execute",
						order = 4,
						name = L.btnRevert,
						hidden = dirtyHidden,
						func = function()
							handle(service:revertToProfile())
						end,
					},
					hdrProfiles = { type = "header", order = 10, name = L.hdrProfiles },
					profile = {
						type = "select",
						order = 11,
						width = "double",
						name = L.selectProfile,
						values = function()
							local values = {}
							for _, p in ipairs(service:listProfiles()) do
								values[p.key] = p.name
							end
							return values
						end,
						get = function()
							return selectedProfile() and selected or nil
						end,
						set = function(_, value)
							selected = value
							Options.refresh()
						end,
						disabled = noProfile,
					},
					-- Mode and Bartender4 profile are read-only facts recorded at save time.
					-- To move a profile to the other mode, use "Convert".
					card = {
						type = "description",
						order = 12,
						fontSize = "medium",
						name = function()
							local p = selectedProfile()
							if not p then
								return L.noProfiles
							end
							local lines = { L.cardMode:format(Format.mode(L, p.mode)) }
							if p.mode == "bt4" and p.bt4Profile then
								lines[#lines + 1] = L.cardBT4Profile:format(p.bt4Profile)
							end
							local inactive = ns.Util.count(p.inactive)
							if inactive > 0 then
								lines[#lines + 1] = L.cardCountsInactive:format(ns.Util.count(p.bindings), inactive)
							else
								lines[#lines + 1] = L.cardCounts:format(ns.Util.count(p.bindings))
							end
							lines[#lines + 1] = L.cardDates:format(Format.date(p.createdAt), Format.date(p.updatedAt))
							return table.concat(lines, "\n")
						end,
					},
					apply = {
						type = "execute",
						order = 20,
						name = L.btnApply,
						disabled = noProfile,
						func = function()
							handle(service:requestApply(selected))
						end,
					},
					rename = {
						type = "execute",
						order = 21,
						name = L.btnRename,
						disabled = noProfile,
						func = function()
							local p = selectedProfile()
							ns.Popups.input(L.promptRename, p.name, function(text)
								selectAfter(service:rename(p.name, text))
							end)
						end,
					},
					duplicate = {
						type = "execute",
						order = 22,
						name = L.btnDuplicate,
						disabled = noProfile,
						func = function()
							local p = selectedProfile()
							ns.Popups.input(L.promptDuplicate, p.name .. " 2", function(text)
								selectAfter(service:duplicate(p.name, text))
							end)
						end,
					},
					delete = {
						type = "execute",
						order = 23,
						name = L.btnDelete,
						disabled = noProfile,
						func = function()
							local p = selectedProfile()
							ns.Popups.confirm(L.confirmDelete:format(p.name), function()
								selected = nil
								handle(service:delete(p.name))
							end)
						end,
					},
					convert = {
						type = "execute",
						order = 24,
						name = L.btnConvert,
						disabled = noProfile,
						func = function()
							local p = selectedProfile()
							local target = p.mode == "bt4" and "blizzard" or "bt4"
							ns.Popups.input(L.promptConvertName, service:defaultConvertName(p.name, target), function(text)
								selectAfter(service:convert(p.name, target, text))
							end)
						end,
					},
					export = {
						type = "execute",
						order = 25,
						name = L.btnExport,
						disabled = noProfile,
						func = function()
							handle(service:exportProfile(selected))
						end,
					},
					hdrActions = { type = "header", order = 30, name = L.hdrActions },
					saveAs = {
						type = "execute",
						order = 31,
						name = L.btnSaveAs,
						func = function()
							ns.Popups.input(L.promptSaveName, "", function(text)
								selectAfter(service:saveCurrent(text))
							end)
						end,
					},
					import = {
						type = "execute",
						order = 32,
						name = L.btnImport,
						func = function()
							ns.Windows.showImport()
						end,
					},
					undo = {
						type = "execute",
						order = 33,
						name = L.btnUndo,
						func = function()
							handle(service:undo())
						end,
					},
				},
			},
			common = {
				type = "group",
				name = L.tabCommon,
				order = 2,
				args = {
					desc = { type = "description", order = 1, name = L.commonDesc },
					groups = {
						type = "multiselect",
						order = 2,
						name = L.commonGroups,
						values = function()
							local values = {}
							for _, g in ipairs((service:groupsInfo()).list) do
								if g.selectable then
									values[g.key] = g.label
								end
							end
							return values
						end,
						get = function(_, key)
							return service:settings().commonGroups[key] == true
						end,
						set = function(_, key, value)
							handle(service:setCommonGroup(key, value))
						end,
					},
					notSelectable = {
						type = "description",
						order = 3,
						name = function()
							local labels = {}
							for _, g in ipairs((service:groupsInfo()).list) do
								if not g.selectable then
									labels[#labels + 1] = g.label
								end
							end
							return L.commonNotSelectable:format(table.concat(labels, ", "))
						end,
					},
					allWarning = {
						type = "description",
						order = 4,
						name = "|cffff6060" .. L.warnAllCommon .. "|r",
						hidden = function()
							local groups, common = service:groupsInfo()
							return not ns.Groups.allSelected(groups, common)
						end,
					},
				},
			},
			settings = {
				type = "group",
				name = L.tabSettings,
				order = 3,
				args = {
					bindingSet = {
						type = "select",
						order = 1,
						width = "double",
						name = L.settingBindingSet,
						desc = L.settingBindingSetDesc,
						values = function()
							return { character = L.set_character, account = L.set_account }
						end,
						get = function()
							return service:settings().bindingSet
						end,
						set = function(_, value)
							handle(service:setBindingSet(value))
						end,
					},
					rememberBT4 = {
						type = "toggle",
						order = 2,
						width = "full",
						name = L.settingRememberBT4,
						get = function()
							return service:settings().rememberBT4Profile
						end,
						set = function(_, value)
							handle(service:setRememberBT4(value))
						end,
					},
				},
			},
			history = {
				type = "group",
				name = L.tabHistory,
				order = 4,
				args = {
					desc = { type = "description", order = 1, name = L.historyDesc },
					list = {
						type = "select",
						order = 2,
						width = "full",
						name = L.historySelect,
						values = function()
							local values = {}
							for _, e in ipairs(service:listHistory()) do
								values[e.id] = ("#%d  %s  %s%s"):format(e.id, Format.date(e.at), L["op_" .. e.op],
									e.profileName and (" - " .. e.profileName) or "")
							end
							return values
						end,
						get = function()
							return selectedHistory
						end,
						set = function(_, value)
							selectedHistory = value
						end,
					},
					restore = {
						type = "execute",
						order = 3,
						name = L.btnRestore,
						disabled = function()
							return selectedHistory == nil
						end,
						func = function()
							local id = selectedHistory
							ns.Popups.confirm(L.confirmRestore, function()
								selectedHistory = nil
								handle(service:restore(id))
							end)
						end,
					},
					undo = {
						type = "execute",
						order = 4,
						name = L.btnUndo,
						func = function()
							handle(service:undo())
						end,
					},
				},
			},
		},
	}
end

function Options.register()
	LibStub("AceConfig-3.0"):RegisterOptionsTable(APP, buildOptions())
	panelFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(APP, "BindShifter")
	panelFrame:HookScript("OnShow", function()
		visible = true
		Options.refresh()
	end)
	panelFrame:HookScript("OnHide", function()
		visible = false
	end)
end

function Options.open()
	if not panelFrame then
		return
	end
	-- 3.3.5: the first call may only open the frame without selecting the category.
	InterfaceOptionsFrame_OpenToCategory(panelFrame)
	InterfaceOptionsFrame_OpenToCategory(panelFrame)
end
