-- Slash commands /bindshifter and /bsh (contracts/slash-commands.md).
local _, ns = ...

local Slash = {}
ns.Slash = Slash

-- Pure parser: returns { cmd = lowercased sub-command or "", arg = rest of the line }.
function Slash.parse(input)
	input = tostring(input or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local cmd, rest = input:match("^(%S+)%s*(.-)$")
	return { cmd = cmd and cmd:lower() or "", arg = rest or "" }
end

-- Sub-commands listed by "help". "diag" is intentionally hidden.
Slash.HELP = { "helpOpen", "helpList", "helpSave", "helpApply", "helpUndo", "helpHelp" }

local function needName(L, arg)
	if arg == "" then
		ns.Chat.print(L, "errNameEmpty")
		return false
	end
	return true
end

function Slash.run(input)
	if not ns.ui then
		return
	end
	local service, L = ns.ui.service, ns.ui.L
	local Chat, Windows = ns.Chat, ns.Windows
	local p = Slash.parse(input)

	if p.cmd == "" then
		ns.Options.open()
	elseif p.cmd == "help" then
		Chat.raw(L.helpHeader)
		for _, key in ipairs(Slash.HELP) do
			DEFAULT_CHAT_FRAME:AddMessage("  " .. L[key])
		end
	elseif p.cmd == "list" then
		local list = service:listProfiles()
		if #list == 0 then
			Chat.print(L, "noProfiles")
			return
		end
		local dirty = service:dirtyCount()
		Chat.raw(L.listHeader)
		for _, item in ipairs(list) do
			local line = ("  %s%s - %s - %d"):format(item.active and "* " or "", item.name,
				ns.Format.mode(L, item.mode), item.count)
			if item.active and dirty > 0 then
				line = line .. "  |cffffd100" .. L.dirtyMark:format(dirty) .. "|r"
			end
			DEFAULT_CHAT_FRAME:AddMessage(line)
		end
	elseif p.cmd == "save" then
		if needName(L, p.arg) then
			Windows.handle(service:saveCurrent(p.arg))
		end
	elseif p.cmd == "apply" then
		if needName(L, p.arg) then
			Windows.handle(service:requestApply(p.arg))
		end
	elseif p.cmd == "undo" then
		Windows.handle(service:undo())
	elseif p.cmd == "diag" then
		local d = service:diag()
		Chat.raw(("mode=%s clientSet=%s configuredSet=%s keys=%s captureMs=%.1f lastApplyMs=%s changed=%s profiles=%d history=%d readOnly=%s")
			:format(d.mode, tostring(d.clientSet), d.configuredSet, tostring(d.keys), d.captureMs or 0,
				d.lastApplyMs and ("%.1f"):format(d.lastApplyMs) or "-", tostring(d.lastApplyChanged or "-"),
				d.profiles, d.history, tostring(d.readOnly)))
	else
		Chat.print(L, "errUnknownCommand", p.cmd)
	end
end

function Slash.register(addon)
	addon:RegisterChatCommand("bindshifter", Slash.run)
	addon:RegisterChatCommand("bsh", Slash.run)
end
