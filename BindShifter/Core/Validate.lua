-- Checks that the actions of a BindingMap exist for this character (research.md R14, FR-013).
-- Problems are warnings: the bindings are still applied and stay in the profile.
local _, ns = ...

local Validate = {}
ns.Validate = Validate

local Commands, Util = ns.Commands, ns.Util

-- Per-operation cache so the spellbook is read once.
function Validate.newContext(api)
	return { api = api }
end

local function spells(ctx)
	if not ctx.spells then
		ctx.spells = ctx.api.knownSpells() or {}
	end
	return ctx.spells
end

-- Returns the issue reason for one command, or nil when it looks usable.
function Validate.check(ctx, cmd)
	local parsed = Commands.parse(cmd)
	local api = ctx.api
	if parsed.kind == "spell" then
		if not spells(ctx)[parsed.name] then
			return "unknownSpell"
		end
	elseif parsed.kind == "macro" then
		if not api.macroExists(parsed.name) then
			return "missingMacro"
		end
	elseif parsed.kind == "item" then
		if (api.itemCount(parsed.name) or 0) <= 0 then
			return "missingItem"
		end
	elseif parsed.frame then
		if not api.frameExists(parsed.frame) then
			return "missingFrame"
		end
	end
	return nil
end

-- Returns a sorted list of { key, command, reason } for the given bindings.
function Validate.issues(ctx, bindings)
	local out = {}
	for _, key in ipairs(Util.sortedKeys(bindings)) do
		local reason = Validate.check(ctx, bindings[key])
		if reason then
			out[#out + 1] = { key = key, command = bindings[key], reason = reason }
		end
	end
	return out
end
