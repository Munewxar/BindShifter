-- Applies a Diff to the client and verifies the result (research.md R4, FR-010).
local _, ns = ...

local Apply = {}
ns.Apply = Apply

local Snapshot, Util = ns.Snapshot, ns.Util

-- Applies `diff` and saves to `set` ("character" | "account").
-- Returns a report { changed = n, issues = { {key, command, reason} } }.
-- The caller guarantees that the player is not in combat.
function Apply.run(api, diff, set)
	local report = { changed = 0, issues = {} }
	local expected = {}

	-- Switch the client to the target set before changing anything. Other addons
	-- (Bartender4's ReassignBindings) may call SaveBindings(GetCurrentBindingSet())
	-- in the middle of our changes; this keeps such saves in the right set (principle V).
	if api.currentBindingSet() ~= set then
		api.saveBindings(set)
	end

	for _, key in ipairs(Util.sortedKeys(diff.removed)) do
		if api.setBinding(key, nil) then
			report.changed = report.changed + 1
			expected[key] = false
		else
			report.issues[#report.issues + 1] = { key = key, command = diff.removed[key], reason = "rejected" }
		end
	end

	local function assign(key, cmd)
		if api.setBinding(key, cmd) then
			report.changed = report.changed + 1
			expected[key] = cmd
		else
			report.issues[#report.issues + 1] = { key = key, command = cmd, reason = "rejected" }
		end
	end
	for _, key in ipairs(Util.sortedKeys(diff.added)) do
		assign(key, diff.added[key])
	end
	for _, key in ipairs(Util.sortedKeys(diff.changed)) do
		assign(key, diff.changed[key].to)
	end

	api.saveBindings(set)

	-- Post-check: the client may silently ignore a binding.
	local after = Snapshot.capture(api)
	for _, key in ipairs(Util.sortedKeys(expected)) do
		local want = expected[key]
		local got = after[key]
		if (want == false and got ~= nil) or (want ~= false and got ~= want) then
			report.issues[#report.issues + 1] = {
				key = key,
				command = want or got,
				reason = "postcheckMismatch",
			}
		end
	end

	return report
end
