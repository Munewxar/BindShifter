-- Bartender4 <-> Blizzard action button mapping (docs/research.md section 3.3, research.md R8).
local _, ns = ...

local SlotMap = {}
ns.SlotMap = SlotMap

local tonumber, format = tonumber, string.format

-- Blizzard multi-action bars by action slot range.
local MULTI = {
	{ bar = 3, first = 25 }, -- MultiBarRight
	{ bar = 4, first = 37 }, -- MultiBarLeft (right 2)
	{ bar = 2, first = 49 }, -- MultiBarBottomRight
	{ bar = 1, first = 61 }, -- MultiBarBottomLeft
}
local MULTI_BY_BAR = {}
for _, m in ipairs(MULTI) do
	MULTI_BY_BAR[m.bar] = m
end

-- Parses a bar button command into a descriptor, or nil if it is not one.
-- family: "main" | "multi" | "pet" | "stance" | "bt4" | "bt4pet" | "bt4stance"
function SlotMap.describe(cmd)
	if type(cmd) ~= "string" then
		return nil
	end
	local n = tonumber(cmd:match("^ACTIONBUTTON(%d+)$"))
	if n and n >= 1 and n <= 12 then
		return { family = "main", index = n, slot = n }
	end
	local bar, idx = cmd:match("^MULTIACTIONBAR(%d)BUTTON(%d+)$")
	bar, idx = tonumber(bar), tonumber(idx)
	if bar and MULTI_BY_BAR[bar] and idx >= 1 and idx <= 12 then
		return { family = "multi", bar = bar, index = idx, slot = MULTI_BY_BAR[bar].first + idx - 1 }
	end
	n = tonumber(cmd:match("^BONUSACTIONBUTTON(%d+)$"))
	if n and n >= 1 and n <= 10 then
		return { family = "pet", index = n }
	end
	n = tonumber(cmd:match("^SHAPESHIFTBUTTON(%d+)$"))
	if n and n >= 1 and n <= 10 then
		return { family = "stance", index = n }
	end
	n = tonumber(cmd:match("^CLICK BT4Button(%d+):LeftButton$"))
	if n and n >= 1 and n <= 120 then
		return { family = "bt4", slot = n }
	end
	n = tonumber(cmd:match("^CLICK BT4PetButton(%d+):LeftButton$"))
	if n and n >= 1 and n <= 10 then
		return { family = "bt4pet", index = n }
	end
	n = tonumber(cmd:match("^CLICK BT4StanceButton(%d+):LeftButton$"))
	if n and n >= 1 and n <= 10 then
		return { family = "bt4stance", index = n }
	end
	return nil
end

function SlotMap.isBarCommand(cmd)
	return SlotMap.describe(cmd) ~= nil
end

-- Action slot for main/multi/bt4 buttons; nil for pet and stance.
function SlotMap.slotOf(cmd)
	local d = SlotMap.describe(cmd)
	return d and d.slot or nil
end

local function multiForSlot(slot)
	for _, m in ipairs(MULTI) do
		if slot >= m.first and slot <= m.first + 11 then
			return format("MULTIACTIONBAR%dBUTTON%d", m.bar, slot - m.first + 1)
		end
	end
	return nil
end

-- Returns result, status. status: "same" (unchanged), "mapped", "untranslatable".
function SlotMap.toBlizzard(cmd)
	local d = SlotMap.describe(cmd)
	if not d then
		return cmd, "same"
	end
	if d.family == "bt4" then
		if d.slot <= 12 then
			return format("ACTIONBUTTON%d", d.slot), "mapped"
		end
		local multi = multiForSlot(d.slot)
		if multi then
			return multi, "mapped"
		end
		return nil, "untranslatable"
	elseif d.family == "bt4pet" then
		return format("BONUSACTIONBUTTON%d", d.index), "mapped"
	elseif d.family == "bt4stance" then
		return format("SHAPESHIFTBUTTON%d", d.index), "mapped"
	end
	return cmd, "same"
end

-- Bartender4 4.4.x handles ACTIONBUTTON, BONUSACTIONBUTTON and SHAPESHIFTBUTTON itself,
-- so only the multi-action bars need rewriting.
function SlotMap.toBT4(cmd)
	local d = SlotMap.describe(cmd)
	if d and d.family == "multi" then
		return format("CLICK BT4Button%d:LeftButton", d.slot), "mapped"
	end
	return cmd, "same"
end

-- Mapping function for converting a profile into `targetMode`.
function SlotMap.mapperFor(targetMode)
	if targetMode == "blizzard" then
		return SlotMap.toBlizzard
	end
	return SlotMap.toBT4
end
