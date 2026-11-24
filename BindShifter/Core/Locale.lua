-- Locale selection with enUS fallback. Pure: the client locale is passed in.
local _, ns = ...

local Locale = {}
ns.Locale = Locale

-- Builds the string table for `locale` from ns.Locales.
-- Missing keys fall back to enUS, then to the key itself.
function Locale.build(locale, tables)
	tables = tables or ns.Locales or {}
	local base = tables.enUS or {}
	local chosen = tables[locale] or {}
	return setmetatable({}, {
		__index = function(_, key)
			local value = chosen[key]
			if value == nil then
				value = base[key]
			end
			if value == nil then
				value = key
			end
			return value
		end,
	})
end
