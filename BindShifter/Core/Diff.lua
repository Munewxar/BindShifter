-- Difference between live bindings and a target BindingMap (data-model.md: Diff).
local _, ns = ...

local Diff = {}
ns.Diff = Diff

local function never()
	return false
end

-- live, target: BindingMap. isCommon(cmd) -> true for shared commands (FR-081..FR-083).
function Diff.compute(live, target, isCommon)
	isCommon = isCommon or never
	local d = { added = {}, changed = {}, removed = {}, skippedCommon = {}, conflicts = {}, count = 0 }

	for key, cmd in pairs(target) do
		local current = live[key]
		if isCommon(cmd) then
			d.skippedCommon[key] = cmd
		elseif current ~= nil and isCommon(current) then
			d.conflicts[key] = { profile = cmd, common = current }
		elseif current == nil then
			d.added[key] = cmd
			d.count = d.count + 1
		elseif current ~= cmd then
			d.changed[key] = { from = current, to = cmd }
			d.count = d.count + 1
		end
	end

	for key, cmd in pairs(live) do
		if not isCommon(cmd) then
			local wanted = target[key]
			if wanted == nil or isCommon(wanted) then
				d.removed[key] = cmd
				d.count = d.count + 1
			end
		end
	end

	return d
end

-- Drops keys from a diff (used to ignore inactive keys in the "changed" mark).
function Diff.without(d, keys)
	for key in pairs(keys or {}) do
		if d.added[key] or d.changed[key] or d.removed[key] then
			d.count = d.count - 1
		end
		d.added[key], d.changed[key], d.removed[key] = nil, nil, nil
	end
	return d
end
