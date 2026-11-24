-- Binding command classification (data-model.md: Command, CommandKind).
local _, ns = ...

local Commands = {}
ns.Commands = Commands

local SlotMap = ns.SlotMap

-- Normalizes a command string as returned by the client (research.md R17, spike S7).
-- Returns nil for empty commands.
function Commands.normalize(cmd)
	if type(cmd) ~= "string" then
		return nil
	end
	cmd = cmd:gsub("^%s+", ""):gsub("%s+$", "")
	if cmd == "" then
		return nil
	end
	-- "CLICK Frame" without a mouse button means LeftButton.
	local frame = cmd:match("^CLICK ([^:]+)$")
	if frame then
		cmd = "CLICK " .. frame .. ":LeftButton"
	end
	return cmd
end

-- Returns a table describing the command:
-- { kind = "bar"|"spell"|"macro"|"item"|"click"|"named", name?, frame?, button?, bar? }
function Commands.parse(cmd)
	local bar = SlotMap.describe(cmd)
	local frame, button = cmd:match("^CLICK ([^:]+):(.+)$")
	if bar then
		return { kind = "bar", bar = bar, frame = frame, button = button }
	end
	local name = cmd:match("^SPELL (.+)$")
	if name then
		return { kind = "spell", name = name }
	end
	name = cmd:match("^MACRO (.+)$")
	if name then
		return { kind = "macro", name = name }
	end
	name = cmd:match("^ITEM (.+)$")
	if name then
		return { kind = "item", name = name }
	end
	if frame then
		return { kind = "click", frame = frame, button = button }
	end
	return { kind = "named" }
end

function Commands.classify(cmd)
	return Commands.parse(cmd).kind
end
