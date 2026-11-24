-- Action bar mode detection and mismatch analysis (research.md R6/R7, FR-030..FR-038).
local _, ns = ...

local Mode = {}
ns.Mode = Mode

local SlotMap, Util = ns.SlotMap, ns.Util

Mode.BT4 = "Bartender4"

function Mode.current(api)
	return api.isAddonLoaded(Mode.BT4) and "bt4" or "blizzard"
end

function Mode.bt4Installed(api)
	return api.isAddonInstalled(Mode.BT4)
end

function Mode.needsSwitch(profile, currentMode)
	return profile.mode ~= currentMode
end

-- Bindings of `profile` that will not work as expected in `currentMode`.
-- Returns a sorted list of { key, command, reason }:
--   "missingFrame" - Bartender4 buttons while Bartender4 is not loaded;
--   "hiddenBar"    - standard multi-action bars, hidden while Bartender4 is loaded
--                    (whether the key still fires is spike S2).
function Mode.unusable(profile, currentMode)
	local out = {}
	for _, key in ipairs(Util.sortedKeys(profile.bindings)) do
		local cmd = profile.bindings[key]
		local d = SlotMap.describe(cmd)
		if d then
			local isBT4 = d.family == "bt4" or d.family == "bt4pet" or d.family == "bt4stance"
			if currentMode == "blizzard" and isBT4 then
				out[#out + 1] = { key = key, command = cmd, reason = "missingFrame" }
			elseif currentMode == "bt4" and d.family == "multi" then
				out[#out + 1] = { key = key, command = cmd, reason = "hiddenBar" }
			end
		end
	end
	return out
end
