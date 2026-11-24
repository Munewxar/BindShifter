-- Profile export/import strings (contracts/export-format.md, research.md R9).
-- The serializer (AceSerializer-3.0) and LibDeflate are injected.
local _, ns = ...

local Codec = {}
ns.Codec = Codec
Codec.__index = Codec

local Keys, Store = ns.Keys, ns.Store

Codec.PREFIX = "BSH1:"
Codec.FORMAT_VERSION = 1

-- formatMigrations[v] upgrades payload data from format v to v + 1 (FR-065).
Codec.formatMigrations = {}

function Codec.new(deps)
	return setmetatable({ serializer = deps.serializer, deflate = deps.deflate }, Codec)
end

local function copyMap(map)
	local out = {}
	for k, v in pairs(map or {}) do
		out[k] = v
	end
	return out
end

function Codec:encode(profile)
	local data = {
		formatVersion = Codec.FORMAT_VERSION,
		kind = "profile",
		profile = {
			name = profile.name,
			mode = profile.mode,
			bt4Profile = profile.bt4Profile,
			bindings = copyMap(profile.bindings),
			inactive = copyMap(profile.inactive),
			origin = copyMap(profile.origin),
		},
	}
	local serialized = self.serializer:Serialize(data)
	local compressed = self.deflate:CompressDeflate(serialized)
	return Codec.PREFIX .. self.deflate:EncodeForPrint(compressed)
end

local function validMap(map)
	if map == nil then
		return {}
	end
	if type(map) ~= "table" then
		return nil
	end
	local out = {}
	for k, v in pairs(map) do
		if type(k) ~= "string" or type(v) ~= "string" then
			return nil
		end
		local key = Keys.normalize(k)
		if not key then
			return nil
		end
		out[key] = v
	end
	return out
end

-- Returns profile data, or nil and an error key (contracts/export-format.md, rule 3).
function Codec:decode(str)
	if type(str) ~= "string" then
		return nil, "errPrefix"
	end
	str = str:gsub("%s+", "")
	if str:sub(1, #Codec.PREFIX) ~= Codec.PREFIX then
		return nil, "errPrefix"
	end
	local body = str:sub(#Codec.PREFIX + 1)
	local decoded = self.deflate:DecodeForPrint(body)
	if not decoded then
		return nil, "errDecode"
	end
	local serialized = self.deflate:DecompressDeflate(decoded)
	if not serialized then
		return nil, "errDecompress"
	end
	local ok, data = self.serializer:Deserialize(serialized)
	if not ok or type(data) ~= "table" then
		return nil, "errDeserialize"
	end
	if data.kind ~= "profile" or type(data.formatVersion) ~= "number" or type(data.profile) ~= "table" then
		return nil, "errSchema"
	end
	if data.formatVersion > Codec.FORMAT_VERSION then
		return nil, "errNewerVersion"
	end
	local version = data.formatVersion
	while version < Codec.FORMAT_VERSION do
		local step = Codec.formatMigrations[version]
		if not step then
			return nil, "errSchema"
		end
		step(data)
		version = version + 1
	end

	local p = data.profile
	if not Store.validateName(p.name) then
		return nil, "errSchema"
	end
	if p.mode ~= "bt4" and p.mode ~= "blizzard" then
		return nil, "errSchema"
	end
	if p.bt4Profile ~= nil and type(p.bt4Profile) ~= "string" then
		return nil, "errSchema"
	end
	local bindings, inactive, origin = validMap(p.bindings), validMap(p.inactive), validMap(p.origin)
	if not bindings or not inactive or not origin then
		return nil, "errSchema"
	end
	return {
		name = p.name,
		mode = p.mode,
		bt4Profile = p.bt4Profile,
		bindings = bindings,
		inactive = inactive,
		origin = origin,
	}
end
