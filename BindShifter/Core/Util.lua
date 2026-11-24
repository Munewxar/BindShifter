-- Generic helpers shared by Core modules. Pure Lua 5.1.
local _, ns = ...

local Util = {}
ns.Util = Util

local type, pairs, next = type, pairs, next
local sort = table.sort

function Util.deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[Util.deepCopy(k)] = Util.deepCopy(v)
	end
	return copy
end

function Util.deepEqual(a, b)
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in pairs(a) do
		if not Util.deepEqual(v, b[k]) then
			return false
		end
	end
	for k in pairs(b) do
		if a[k] == nil then
			return false
		end
	end
	return true
end

function Util.trim(s)
	if type(s) ~= "string" then
		return ""
	end
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function Util.sortedKeys(t)
	local keys = {}
	for k in pairs(t or {}) do
		keys[#keys + 1] = k
	end
	sort(keys, function(x, y)
		return tostring(x) < tostring(y)
	end)
	return keys
end

function Util.count(t)
	local n = 0
	for _ in pairs(t or {}) do
		n = n + 1
	end
	return n
end

function Util.isEmpty(t)
	return t == nil or next(t) == nil
end

-- Number of UTF-8 characters (continuation bytes 0x80-0xBF are not counted).
function Util.utf8len(s)
	local _, continuation = s:gsub("[\128-\191]", "")
	return #s - continuation
end

-- First `n` UTF-8 characters of `s`.
function Util.utf8truncate(s, n)
	if Util.utf8len(s) <= n then
		return s
	end
	local count, i = 0, 1
	while i <= #s do
		local byte = s:byte(i)
		if byte < 128 or byte >= 192 then
			count = count + 1
			if count > n then
				return s:sub(1, i - 1)
			end
		end
		i = i + 1
	end
	return s
end

-- Lowercase for ASCII and Cyrillic (UTF-8). string.lower only handles ASCII.
function Util.lower(s)
	s = s:lower()
	-- А-П (D0 90..D0 9F) -> а-п (D0 B0..D0 BF)
	s = s:gsub("\208([\144-\159])", function(c)
		return "\208" .. string.char(c:byte() + 32)
	end)
	-- Р-Я (D0 A0..D0 AF) -> р-я (D1 80..D1 8F)
	s = s:gsub("\208([\160-\175])", function(c)
		return "\209" .. string.char(c:byte() - 32)
	end)
	-- Ё (D0 81) -> ё (D1 91)
	s = s:gsub("\208\129", "\209\145")
	return s
end
