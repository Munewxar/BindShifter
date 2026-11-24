-- Key names and modifier normalization (data-model.md: Key).
local _, ns = ...

local Keys = {}
ns.Keys = Keys

-- Base keys enumerated by the snapshot (research.md R3).
local BASE = {}
do
	local function add(...)
		for i = 1, select("#", ...) do
			BASE[#BASE + 1] = select(i, ...)
		end
	end
	for c = string.byte("A"), string.byte("Z") do
		add(string.char(c))
	end
	for d = 0, 9 do
		add(tostring(d))
	end
	for f = 1, 19 do
		add("F" .. f)
	end
	for n = 0, 9 do
		add("NUMPAD" .. n)
	end
	add("NUMPADDECIMAL", "NUMPADPLUS", "NUMPADMINUS", "NUMPADMULTIPLY", "NUMPADDIVIDE", "NUMPADENTER")
	add("INSERT", "DELETE", "HOME", "END", "PAGEUP", "PAGEDOWN", "UP", "DOWN", "LEFT", "RIGHT")
	add("TAB", "SPACE", "ENTER", "BACKSPACE", "ESCAPE")
	add("`", "-", "=", "[", "]", "\\", ";", "'", ",", ".", "/")
	add("PRINTSCREEN", "SCROLLLOCK", "PAUSE", "CAPSLOCK", "NUMLOCK")
	for b = 1, 31 do
		add("BUTTON" .. b)
	end
	add("MOUSEWHEELUP", "MOUSEWHEELDOWN")
end
Keys.BASE = BASE

-- Canonical modifier order: ALT, CTRL, SHIFT.
Keys.MODIFIERS = { "ALT", "CTRL", "SHIFT" }
Keys.PREFIXES = {
	"",
	"ALT-",
	"CTRL-",
	"SHIFT-",
	"ALT-CTRL-",
	"ALT-SHIFT-",
	"CTRL-SHIFT-",
	"ALT-CTRL-SHIFT-",
}

local allKeysCache

function Keys.allKeys()
	if not allKeysCache then
		allKeysCache = {}
		for _, prefix in ipairs(Keys.PREFIXES) do
			for _, base in ipairs(BASE) do
				allKeysCache[#allKeysCache + 1] = prefix .. base
			end
		end
	end
	return allKeysCache
end

local MOD_ORDER = { ALT = 1, CTRL = 2, SHIFT = 3 }

-- Returns the key with modifiers in canonical order, e.g. "SHIFT-ALT-X" -> "ALT-SHIFT-X".
-- The minus key itself is "-", so "SHIFT--" is a valid key.
function Keys.normalize(key)
	if type(key) ~= "string" or key == "" then
		return nil
	end
	key = key:upper()
	local present = {}
	local rest = key
	while true do
		local mod, tail = rest:match("^(%u+)%-(.+)$")
		if mod and MOD_ORDER[mod] then
			present[mod] = true
			rest = tail
		else
			break
		end
	end
	local out = ""
	for _, mod in ipairs(Keys.MODIFIERS) do
		if present[mod] then
			out = out .. mod .. "-"
		end
	end
	return out .. rest
end
