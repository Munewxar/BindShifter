-- Binding command groups and "shared" bindings (research.md R15, FR-080..FR-083).
local _, ns = ...

local Groups = {}
ns.Groups = Groups

local SlotMap = ns.SlotMap

-- Builds groups from the ordered GetBinding rows.
-- Returns { list = { {key, label, commands, selectable} }, byCommand = { [cmd] = key } }.
function Groups.build(api)
	local list, byCommand, byKey = {}, {}, {}
	local current
	for _, row in ipairs(api.listBindingCommands()) do
		if row.header then
			local key = row.command:gsub("^HEADER_", "")
			-- BLANK headers are spacers inside a group in the 3.3.5 Bindings.xml.
			if not key:match("^BLANK") then
				current = byKey[key]
				if not current then
					current = { key = key, label = api.headerLabel(key), commands = {}, selectable = true }
					byKey[key] = current
					list[#list + 1] = current
				end
			end
		elseif current then
			current.commands[#current.commands + 1] = row.command
			byCommand[row.command] = current.key
			if SlotMap.isBarCommand(row.command) then
				current.selectable = false
			end
		end
	end
	return { list = list, byCommand = byCommand, byKey = byKey }
end

-- Returns isCommon(cmd) for the selected group keys. Non-selectable groups never count.
function Groups.isCommonFn(groups, commonGroups)
	return function(cmd)
		local key = groups.byCommand[cmd]
		if not key or not commonGroups[key] then
			return false
		end
		return groups.byKey[key].selectable
	end
end

-- True when every selectable group is marked as shared.
function Groups.allSelected(groups, commonGroups)
	local any = false
	for _, g in ipairs(groups.list) do
		if g.selectable then
			any = true
			if not commonGroups[g.key] then
				return false
			end
		end
	end
	return any
end
