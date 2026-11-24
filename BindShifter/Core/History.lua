-- Backups and undo history per character (data-model.md: HistoryEntry, CharacterState.history).
local _, ns = ...

local History = {}
ns.History = History

History.LIMIT = 20

-- Appends an entry, assigns id and timestamp, trims to the newest LIMIT entries.
function History.push(charState, entry, now)
	entry.id = charState.nextHistoryId or 1
	charState.nextHistoryId = entry.id + 1
	entry.at = now
	local list = charState.history
	list[#list + 1] = entry
	while #list > History.LIMIT do
		table.remove(list, 1)
	end
	return entry
end

function History.pop(charState)
	local list = charState.history
	local entry = list[#list]
	list[#list] = nil
	return entry
end

function History.peek(charState)
	local list = charState.history
	return list[#list]
end

function History.find(charState, id)
	for _, entry in ipairs(charState.history) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

-- Newest first.
function History.list(charState)
	local out = {}
	for i = #charState.history, 1, -1 do
		out[#out + 1] = charState.history[i]
	end
	return out
end
