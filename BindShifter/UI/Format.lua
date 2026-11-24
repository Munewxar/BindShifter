-- Human-readable keys, commands, dates and issues for the UI.
local _, ns = ...

local Format = {}
ns.Format = Format

local floor = math.floor

function Format.key(key)
	if key == nil or key == "" then
		return ""
	end
	local text = GetBindingText and GetBindingText(key, "KEY_")
	return text or key
end

local MULTI_LABEL = {
	[1] = "barBottomLeft",
	[2] = "barBottomRight",
	[3] = "barRight",
	[4] = "barRight2",
}

function Format.command(L, cmd)
	if cmd == nil then
		return ""
	end
	local p = ns.Commands.parse(cmd)
	if p.kind == "spell" then
		return L.cmdSpell:format(p.name)
	elseif p.kind == "macro" then
		return L.cmdMacro:format(p.name)
	elseif p.kind == "item" then
		return L.cmdItem:format(p.name)
	elseif p.kind == "click" then
		return L.cmdClick:format(p.frame)
	elseif p.kind == "bar" then
		local d = p.bar
		if d.family == "bt4" then
			return L.cmdBT4Button:format(floor((d.slot - 1) / 12) + 1, (d.slot - 1) % 12 + 1)
		elseif d.family == "bt4pet" then
			return L.cmdBT4Pet:format(d.index)
		elseif d.family == "bt4stance" then
			return L.cmdBT4Stance:format(d.index)
		elseif d.family == "main" then
			return L.cmdMainBar:format(d.index)
		elseif d.family == "multi" then
			return L.cmdMultiBar:format(L[MULTI_LABEL[d.bar]], d.index)
		elseif d.family == "pet" then
			return L.cmdPetBar:format(d.index)
		elseif d.family == "stance" then
			return L.cmdStanceBar:format(d.index)
		end
	end
	local text = GetBindingText and GetBindingText(cmd, "BINDING_NAME_")
	return text or cmd
end

function Format.date(ts)
	if not ts then
		return "-"
	end
	return date("%Y-%m-%d %H:%M", ts)
end

function Format.mode(L, mode)
	return L["mode_" .. tostring(mode)]
end

function Format.issue(L, issue)
	local reason = L["reason_" .. issue.reason]
	if issue.key == nil or issue.key == "" then
		return ("%s: %s"):format(reason, tostring(issue.command or ""))
	end
	return ("%s: %s - %s"):format(Format.key(issue.key), Format.command(L, issue.command), reason)
end
