-- SavedVariables schema, defaults and migrations (data-model.md: SavedVariables BindShifterDB).
local _, ns = ...

local Migrations = {}
ns.Migrations = Migrations

Migrations.CURRENT = 1

local SETTINGS_DEFAULTS = {
	bindingSet = "character",
	accountSetAcknowledged = false,
	rememberBT4Profile = true,
}

local function fresh()
	return {
		schemaVersion = Migrations.CURRENT,
		settings = {
			bindingSet = SETTINGS_DEFAULTS.bindingSet,
			accountSetAcknowledged = SETTINGS_DEFAULTS.accountSetAcknowledged,
			rememberBT4Profile = SETTINGS_DEFAULTS.rememberBT4Profile,
			commonGroups = {},
		},
		profiles = {},
		chars = {},
	}
end
Migrations.fresh = fresh

-- steps[v] upgrades a database from version v to v + 1.
local steps = {}
Migrations.steps = steps

local function quarantine(original, now)
	local db = fresh()
	db.quarantine = { at = now, data = original }
	return db, "quarantined"
end

local function normalizeProfile(p)
	if type(p.bindings) ~= "table" then
		p.bindings = {}
	end
	if type(p.inactive) ~= "table" then
		p.inactive = {}
	end
	if type(p.origin) ~= "table" then
		p.origin = {}
	end
	if p.mode ~= "bt4" and p.mode ~= "blizzard" then
		p.mode = "blizzard"
	end
end

-- Returns db, status. status: "fresh" | "ok" | "readOnly" | "quarantined".
-- "readOnly": the data comes from a newer version; it is returned untouched.
function Migrations.run(db, now)
	if db == nil then
		return fresh(), "fresh"
	end
	if type(db) ~= "table" then
		return quarantine(db, now)
	end
	local version = db.schemaVersion
	if version == nil then
		if next(db) == nil then
			return fresh(), "fresh"
		end
		return quarantine(db, now)
	end
	if type(version) ~= "number" or version < 1 or version ~= math.floor(version) then
		return quarantine(db, now)
	end
	if version > Migrations.CURRENT then
		return db, "readOnly"
	end
	while version < Migrations.CURRENT do
		local step = steps[version]
		if not step then
			return quarantine(db, now)
		end
		step(db)
		version = version + 1
		db.schemaVersion = version
	end

	for _, field in ipairs({ "settings", "profiles", "chars" }) do
		if db[field] == nil then
			db[field] = {}
		elseif type(db[field]) ~= "table" then
			return quarantine(db, now)
		end
	end
	local settings = db.settings
	for k, v in pairs(SETTINGS_DEFAULTS) do
		if settings[k] == nil then
			settings[k] = v
		end
	end
	if type(settings.commonGroups) ~= "table" then
		settings.commonGroups = {}
	end
	for name, p in pairs(db.profiles) do
		if type(p) ~= "table" or type(p.name) ~= "string" then
			db.profiles[name] = nil
			db.quarantine = db.quarantine or { at = now, data = { profiles = {} } }
			db.quarantine.data.profiles = db.quarantine.data.profiles or {}
			db.quarantine.data.profiles[name] = p
		else
			normalizeProfile(p)
		end
	end
	return db, "ok"
end

-- Returns the CharacterState for `charKey`, creating it when missing.
function Migrations.ensureChar(db, charKey)
	local c = db.chars[charKey]
	if type(c) ~= "table" then
		c = {}
		db.chars[charKey] = c
	end
	if type(c.history) ~= "table" then
		c.history = {}
	end
	c.nextHistoryId = c.nextHistoryId or 1
	return c
end
