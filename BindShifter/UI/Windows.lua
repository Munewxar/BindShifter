-- AceGUI windows (contracts/ui-panel.md) and the dispatcher that renders Service steps.
local _, ns = ...

local Windows = {}
ns.Windows = Windows

local AceGUI
local openWindows = {}
local cleanups = {} -- [window] = { fn, ... } run before the window is released

local function ui()
	return ns.ui.service, ns.ui.L
end

local function refresh()
	if ns.Options and ns.Options.refresh then
		ns.Options.refresh()
	end
end

function Windows.close(kind)
	local w = openWindows[kind]
	if w then
		w:Hide()
	end
end

-- Creates (or replaces) a window of `kind`.
local function newWindow(kind, title, width, height)
	AceGUI = AceGUI or LibStub("AceGUI-3.0")
	Windows.close(kind)
	local f = AceGUI:Create("Frame")
	f:SetTitle(title)
	f:SetLayout("Flow")
	f:SetWidth(width or 560)
	f:SetHeight(height or 460)
	f:SetCallback("OnClose", function(widget)
		if openWindows[kind] == widget then
			openWindows[kind] = nil
		end
		for _, fn in ipairs(cleanups[widget] or {}) do
			fn()
		end
		cleanups[widget] = nil
		AceGUI:Release(widget)
	end)
	openWindows[kind] = f
	return f
end

local function addScrollText(f, text, height)
	local box = AceGUI:Create("SimpleGroup")
	box:SetFullWidth(true)
	box:SetHeight(height or 300)
	box:SetLayout("Fill")
	f:AddChild(box)
	local scroll = AceGUI:Create("ScrollFrame")
	scroll:SetLayout("List")
	box:AddChild(scroll)
	local label = AceGUI:Create("Label")
	label:SetFullWidth(true)
	label:SetText(text)
	scroll:AddChild(label)
	return label
end

-- Creates a MultiLineEditBox without its Accept button. AceGUI pools widgets and does
-- not re-show the button on acquire, so it is shown again before the window is released.
local function addEditBox(f, lines)
	local box = AceGUI:Create("MultiLineEditBox")
	box:SetLabel("")
	box:SetFullWidth(true)
	box:SetNumLines(lines)
	if box.button then
		box.button:Hide()
		cleanups[f] = cleanups[f] or {}
		table.insert(cleanups[f], function()
			box.button:Show()
		end)
	end
	f:AddChild(box)
	return box
end

local function addLabel(f, text)
	local label = AceGUI:Create("Label")
	label:SetFullWidth(true)
	label:SetText(text)
	f:AddChild(label)
	return label
end

local function addButton(f, text, onClick, width, disabled)
	local b = AceGUI:Create("Button")
	b:SetText(text)
	b:SetWidth(width or 160)
	b:SetCallback("OnClick", onClick)
	if disabled then
		b:SetDisabled(true)
	end
	f:AddChild(b)
	return b
end

local GREEN, YELLOW, RED, GREY = "|cff40ff40", "|cffffd100", "|cffff6060", "|cffa0a0a0"

local function section(lines, color, title, items)
	if #items == 0 then
		return
	end
	lines[#lines + 1] = color .. title .. "|r"
	for _, item in ipairs(items) do
		lines[#lines + 1] = "  " .. item
	end
	lines[#lines + 1] = ""
end

local function diffLines(L, diff)
	local Format, Util = ns.Format, ns.Util
	local added, changed, removed = {}, {}, {}
	for _, key in ipairs(Util.sortedKeys(diff.added)) do
		added[#added + 1] = ("%s: %s"):format(Format.key(key), Format.command(L, diff.added[key]))
	end
	for _, key in ipairs(Util.sortedKeys(diff.changed)) do
		local c = diff.changed[key]
		changed[#changed + 1] = ("%s: %s -> %s"):format(Format.key(key), Format.command(L, c.from), Format.command(L, c.to))
	end
	for _, key in ipairs(Util.sortedKeys(diff.removed)) do
		removed[#removed + 1] = ("%s: %s"):format(Format.key(key), Format.command(L, diff.removed[key]))
	end
	return added, changed, removed
end

local function issueLines(L, issues)
	local out = {}
	for _, issue in ipairs(issues or {}) do
		out[#out + 1] = ns.Format.issue(L, issue)
	end
	return out
end

-- Preview (FR-011). With readOnly = true it shows "changes since the profile" (FR-052).
function Windows.showPreview(step, readOnly)
	local service, L = ui()
	local diff = step.diff
	local added, changed, removed = diffLines(L, diff)
	local title = readOnly and L.changesTitle:format(step.name) or L.previewTitle:format(step.name)
	local f = newWindow("preview", title)
	f:SetStatusText(L.previewSummary:format(#added, #changed, #removed))

	local lines = {}
	for _, w in ipairs(step.warnings or {}) do
		lines[#lines + 1] = RED .. L[w] .. "|r"
	end
	if #lines > 0 then
		lines[#lines + 1] = ""
	end
	if step.bt4Switch then
		lines[#lines + 1] = YELLOW .. L.previewBT4Switch:format(step.bt4Switch) .. "|r"
		lines[#lines + 1] = ""
	end
	section(lines, GREEN, L.secAdded, added)
	section(lines, YELLOW, L.secChanged, changed)
	section(lines, RED, L.secRemoved, removed)
	section(lines, GREY, L.secIssues, issueLines(L, step.issues))
	if #added + #changed + #removed == 0 and not step.bt4Switch then
		lines[#lines + 1] = L.noDifferences
	end
	addScrollText(f, table.concat(lines, "\n"), 330)

	if readOnly then
		return -- the window has its own Close button
	end
	addButton(f, L.btnApply, function()
		f:Hide()
		Windows.handle(service:confirmApply(step))
	end)
end

-- Mode choice (FR-035, FR-038).
function Windows.showModeChoice(step)
	local service, L = ui()
	local f = newWindow("mode", L.modeChoiceTitle, 560, 380)
	local lines = {
		L.modeChoiceText:format(step.name, ns.Format.mode(L, step.profileMode), ns.Format.mode(L, step.currentMode)),
		"",
	}
	local canSwitch = step.profileMode ~= "bt4" or step.bt4Installed
	if not canSwitch then
		lines[#lines + 1] = RED .. L.modeChoiceNoBT4 .. "|r"
		lines[#lines + 1] = ""
	end
	if step.unusable and #step.unusable > 0 then
		lines[#lines + 1] = L.modeChoiceUnusable:format(#step.unusable)
		for _, issue in ipairs(issueLines(L, step.unusable)) do
			lines[#lines + 1] = "  " .. issue
		end
	end
	addScrollText(f, table.concat(lines, "\n"), 220)
	addButton(f, L.btnSwitchAndApply, function()
		f:Hide()
		Windows.handle(service:confirmModeSwitch(step))
	end, 240, not canSwitch)
	addButton(f, L.btnApplyWithoutSwitch, function()
		f:Hide()
		Windows.handle(service:applyWithoutSwitch(step))
	end, 240)
	if not canSwitch then
		addButton(f, L.btnConvert, function()
			f:Hide()
			Windows.handle(service:convert(step.name))
		end, 240)
	end
end

-- Report (FR-013, FR-016, FR-043).
function Windows.showReport(report, name)
	local _, L = ui()
	local f = newWindow("report", L.reportTitle:format(name or ""), 560, 400)
	f:SetStatusText(L.reportSummary:format(report.changed or 0, #report.issues))
	addScrollText(f, table.concat(issueLines(L, report.issues), "\n"), 280)
end

function Windows.showExport(step)
	local _, L = ui()
	local f = newWindow("export", L.exportTitle:format(step.name), 560, 360)
	addLabel(f, L.exportHint)
	local box = addEditBox(f, 12)
	box:SetText(step.text)
	if box.editBox then
		box.editBox:SetFocus()
		box.editBox:HighlightText()
	end
end

function Windows.showImport()
	local service, L = ui()
	local f = newWindow("import", L.importTitle, 560, 420)
	addLabel(f, L.importHint)
	local box = addEditBox(f, 10)
	local summary = addLabel(f, "")
	local request
	local importButton, replaceButton

	local function check()
		local step = service:previewImport(box:GetText())
		if step.step ~= "importPreview" then
			request = nil
			summary:SetText(RED .. L[step.err or "errSchema"] .. "|r")
			importButton:SetDisabled(true)
			replaceButton:SetDisabled(true)
			return
		end
		request = step
		local s = step.summary
		local text = L.importSummary:format(s.name, ns.Format.mode(L, s.mode), s.count, s.inactiveCount)
		if step.nameTaken then
			text = text .. "\n" .. YELLOW .. L.importNameTaken .. "|r"
		end
		summary:SetText(text)
		importButton:SetDisabled(false)
		replaceButton:SetDisabled(not step.nameTaken)
	end

	addButton(f, L.btnCheck, check)
	importButton = addButton(f, L.btnImport, function()
		if not request then
			return
		end
		if request.nameTaken then
			-- Close the window first: AceGUI frames sit above StaticPopup dialogs.
			local pending = request
			f:Hide()
			ns.Popups.input(L.promptNewName, pending.data.name .. " 2", function(text)
				Windows.handle(service:confirmImport(pending, { newName = text }))
			end)
		else
			f:Hide()
			Windows.handle(service:confirmImport(request))
		end
	end, 160, true)
	replaceButton = addButton(f, L.btnReplace, function()
		if request then
			f:Hide()
			Windows.handle(service:confirmImport(request, { replace = true }))
		end
	end, 160, true)
end

-- Renders any Service step.
function Windows.handle(step)
	if not step then
		return
	end
	local service, L = ui()
	local kind = step.step
	if kind == "preview" then
		Windows.showPreview(step)
	elseif kind == "needsModeChoice" then
		Windows.showModeChoice(step)
	elseif kind == "done" then
		if step.report and #step.report.issues > 0 then
			Windows.showReport(step.report, step.name)
		end
	elseif kind == "error" then
		ns.Chat.print(L, step.err)
	elseif kind == "confirmOverwrite" then
		local function run(name, overwrite)
			if step.action == "convert" then
				Windows.handle(service:convert(step.source, step.targetMode, name, overwrite))
			else
				Windows.handle(service:saveCurrent(name, overwrite))
			end
		end
		ns.Popups.choice(L.confirmOverwrite:format(step.name), L.btnOverwrite, L.btnOtherName,
			function()
				run(step.name, true)
			end,
			function()
				ns.Popups.input(L.promptNewName, step.name .. " 2", function(text)
					run(text, false)
				end)
			end)
	elseif kind == "confirmRestoreAccount" then
		ns.Popups.confirm(L.confirmRestoreAccount, function()
			if step.action == "restore" then
				Windows.handle(service:restore(step.id, true))
			else
				Windows.handle(service:undo(true))
			end
		end)
	elseif kind == "confirmAccountSet" then
		ns.Popups.confirm(L.confirmAccountSet, function()
			Windows.handle(service:setBindingSet("account", true))
		end)
	elseif kind == "confirmImportName" then
		ns.Popups.input(L.promptNewName, step.name .. " 2", function(text)
			Windows.handle(service:confirmImport(step.request, { newName = text }))
		end)
	elseif kind == "export" then
		Windows.showExport(step)
	end
	refresh()
end
