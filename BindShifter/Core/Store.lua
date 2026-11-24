-- Profile storage (data-model.md: Profile). Operates on the `profiles` and `chars`
-- tables of BindShifterDB; never touches the game.
local _, ns = ...

local Store = {}
ns.Store = Store

local Util = ns.Util

Store.MAX_NAME = 50

-- Key under which a profile is stored: trimmed, case-insensitive.
function Store.normalize(name)
	return Util.lower(Util.trim(name))
end

-- Returns true, or false and an error key.
function Store.validateName(name)
	if type(name) ~= "string" then
		return false, "errNameEmpty"
	end
	local trimmed = Util.trim(name)
	if trimmed == "" then
		return false, "errNameEmpty"
	end
	if Util.utf8len(trimmed) > Store.MAX_NAME then
		return false, "errNameTooLong"
	end
	return true
end

function Store.get(db, name)
	if type(name) ~= "string" then
		return nil
	end
	return db.profiles[Store.normalize(name)]
end

function Store.exists(db, name)
	return Store.get(db, name) ~= nil
end

local function build(name, data, now)
	return {
		name = Util.trim(name),
		mode = data.mode or "blizzard",
		bt4Profile = data.bt4Profile,
		bindings = Util.deepCopy(data.bindings or {}),
		inactive = Util.deepCopy(data.inactive or {}),
		origin = Util.deepCopy(data.origin or {}),
		createdAt = now,
		updatedAt = now,
	}
end

-- Creates a new profile. Returns profile, or nil and an error key.
function Store.create(db, name, data, now)
	local ok, err = Store.validateName(name)
	if not ok then
		return nil, err
	end
	if Store.exists(db, name) then
		return nil, "errNameTaken"
	end
	local profile = build(name, data, now)
	db.profiles[Store.normalize(name)] = profile
	return profile
end

-- Replaces the content of an existing profile, keeping its name and createdAt.
function Store.overwrite(db, name, data, now)
	local old = Store.get(db, name)
	if not old then
		return nil, "errNoProfile"
	end
	local profile = build(old.name, data, now)
	profile.createdAt = old.createdAt
	db.profiles[Store.normalize(name)] = profile
	return profile
end

-- Updates selected fields (mode, bt4Profile, bindings, inactive) in place.
function Store.update(db, name, fields, now)
	local profile = Store.get(db, name)
	if not profile then
		return nil, "errNoProfile"
	end
	for k, v in pairs(fields) do
		if v == false and k == "bt4Profile" then
			profile.bt4Profile = nil
		else
			profile[k] = Util.deepCopy(v)
		end
	end
	profile.updatedAt = now
	return profile
end

function Store.rename(db, oldName, newName, now)
	local profile = Store.get(db, oldName)
	if not profile then
		return nil, "errNoProfile"
	end
	local ok, err = Store.validateName(newName)
	if not ok then
		return nil, err
	end
	local oldKey, newKey = Store.normalize(oldName), Store.normalize(newName)
	if oldKey ~= newKey and db.profiles[newKey] then
		return nil, "errNameTaken"
	end
	db.profiles[oldKey] = nil
	profile.name = Util.trim(newName)
	profile.updatedAt = now
	db.profiles[newKey] = profile
	for _, charState in pairs(db.chars or {}) do
		if charState.activeProfile == oldKey then
			charState.activeProfile = newKey
		end
	end
	return profile
end

function Store.duplicate(db, srcName, newName, now)
	local src = Store.get(db, srcName)
	if not src then
		return nil, "errNoProfile"
	end
	return Store.create(db, newName, src, now)
end

function Store.delete(db, name)
	local key = Store.normalize(name)
	local profile = db.profiles[key]
	if not profile then
		return nil, "errNoProfile"
	end
	db.profiles[key] = nil
	return profile
end

-- Profiles sorted by normalized name.
function Store.list(db)
	local out = {}
	for _, key in ipairs(Util.sortedKeys(db.profiles)) do
		out[#out + 1] = db.profiles[key]
	end
	return out
end
