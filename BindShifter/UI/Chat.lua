-- Prefixed chat output (FR-073).
local _, ns = ...

local Chat = {}
ns.Chat = Chat

Chat.PREFIX = "|cff33ff99BindShifter|r: "

function Chat.raw(text)
	DEFAULT_CHAT_FRAME:AddMessage(Chat.PREFIX .. tostring(text))
end

-- Prints the localized string `key`, formatted with the remaining arguments.
function Chat.print(L, key, ...)
	local text = L[key]
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		if ok then
			text = formatted
		end
	end
	Chat.raw(text)
end
