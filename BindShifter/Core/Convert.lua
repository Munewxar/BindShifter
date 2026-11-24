-- Profile conversion between Bartender4 and Blizzard bars (research.md R8, FR-040..FR-045).
local _, ns = ...

local Convert = {}
ns.Convert = Convert

local SlotMap, Util = ns.SlotMap, ns.Util

-- Converts profile data into `targetMode`.
-- Returns data { mode, bt4Profile, bindings, inactive, origin }, report { changed, issues }.
-- Rules:
--   * a key whose command came from an earlier conversion (origin) and was not changed
--     since then gets its original command back (exact round trip);
--   * other bar commands are mapped by slot; untranslatable ones go to `inactive`;
--   * inactive bindings that fit the target mode become active again;
--   * an active binding wins over an inactive one on the same key (reported).
function Convert.convert(profile, targetMode)
	local forward = SlotMap.mapperFor(targetMode)
	local backward = SlotMap.mapperFor(targetMode == "blizzard" and "bt4" or "blizzard")
	local origin = profile.origin or {}

	local out = {
		mode = targetMode,
		bt4Profile = profile.bt4Profile,
		bindings = {},
		inactive = {},
		origin = {},
	}
	local report = { changed = 0, issues = {} }

	for _, key in ipairs(Util.sortedKeys(profile.bindings)) do
		local cmd = profile.bindings[key]
		local orig = origin[key]
		if orig and backward(orig) == cmd then
			out.bindings[key] = orig
			report.changed = report.changed + 1
		else
			local result, status = forward(cmd)
			if status == "untranslatable" then
				out.inactive[key] = cmd
				report.issues[#report.issues + 1] = { key = key, command = cmd, reason = "untranslatable" }
			elseif status == "mapped" then
				out.bindings[key] = result
				out.origin[key] = cmd
				report.changed = report.changed + 1
			else
				out.bindings[key] = cmd
			end
		end
	end

	for _, key in ipairs(Util.sortedKeys(profile.inactive or {})) do
		local cmd = profile.inactive[key]
		local result, status = forward(cmd)
		if status == "untranslatable" then
			out.inactive[key] = cmd
		elseif out.bindings[key] ~= nil then
			out.inactive[key] = cmd
			report.issues[#report.issues + 1] = { key = key, command = cmd, reason = "conversionConflict" }
		else
			out.bindings[key] = result
			if status == "mapped" then
				out.origin[key] = cmd
			end
			report.changed = report.changed + 1
		end
	end

	return out, report
end
