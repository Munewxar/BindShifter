-- Facade for UI and slash commands. Every user flow lives here and returns a "step"
-- table that the UI renders (plan.md, "Architecture"). No WoW globals: all game
-- access goes through the injected adapter (contracts/wow-adapter.md).
--
-- Steps: { step = "preview" | "needsModeChoice" | "done" | "queued" | "noChanges"
--          | "error" | "confirmOverwrite" | "confirmAccountSet" | "importPreview"
--          | "confirmImportName" | "export" | "reloading", ... }
local _, ns = ...

local Service = {}
ns.Service = Service
Service.__index = Service

local Util, Snapshot, Diff, Validate, Apply = ns.Util, ns.Snapshot, ns.Diff, ns.Validate, ns.Apply
local Store, History, Queue, Groups, Mode = ns.Store, ns.History, ns.Queue, ns.Groups, ns.Mode
local Convert, Migrations, Commands = ns.Convert, ns.Migrations, ns.Commands

local function err(key, extra)
	local step = { step = "error", err = key }
	for k, v in pairs(extra or {}) do
		step[k] = v
	end
	return step
end

-- o = { api, db, codec?, L?, notify?(key, ...), readOnly? }
-- `db` must have the v1 shape. In read-only mode the caller passes a throwaway
-- database so the newer saved data is never touched (data-model.md, Migrations).
function Service.new(o)
	local self = setmetatable({}, Service)
	self.api = o.api
	self.db = o.db
	self.codec = o.codec
	self.L = o.L or setmetatable({}, { __index = function(_, k) return k end })
	self.notifyFn = o.notify or function() end
	self.readOnly = o.readOnly == true
	self.queue = Queue.new()
	self.applying = false
	self.stats = {}
	self.charKey = self.api.charKey()
	self.char = Migrations.ensureChar(self.db, self.charKey)
	return self
end

function Service:notify(key, ...)
	self.notifyFn(key, ...)
end

function Service:now()
	return self.api.now()
end

function Service:settings()
	return self.db.settings
end

function Service:clock()
	return self.api.clock and self.api.clock() or 0
end

-- Snapshot helpers -----------------------------------------------------------

function Service:capture()
	local t0 = self:clock()
	local map = Snapshot.capture(self.api)
	self.stats.captureMs = self:clock() - t0
	self.stats.keys = Util.count(map)
	return map
end

function Service:groups()
	return Groups.build(self.api)
end

function Service:isCommonFn(groups)
	return Groups.isCommonFn(groups or self:groups(), self:settings().commonGroups)
end

local function withoutCommon(map, isCommon)
	local out = {}
	for key, cmd in pairs(map) do
		if not isCommon(cmd) then
			out[key] = cmd
		end
	end
	return out
end

function Service:currentMode()
	return Mode.current(self.api)
end

-- History --------------------------------------------------------------------

-- Settings that a "setChange" backup covers. Shared groups and the Bartender4 toggle
-- are not part of it, so undoing a set change never touches them.
local SET_SETTINGS = { "bindingSet", "accountSetAcknowledged" }

-- fields: { op, profileName?, live?, profiles?, renamed?, settings? }
function Service:backup(fields)
	local entry = {
		op = fields.op,
		profileName = fields.profileName,
		activeProfile = self.char.activeProfile,
		profiles = fields.profiles,
		renamed = fields.renamed,
	}
	if fields.live then
		entry.live = Snapshot.capture(self.api)
		-- The set the client is on right now: undo must write the bindings back there.
		entry.bindingSet = self.api.currentBindingSet()
	end
	if fields.settings then
		entry.settings = {}
		for _, k in ipairs(SET_SETTINGS) do
			entry.settings[k] = self:settings()[k]
		end
	end
	return History.push(self.char, entry, self:now())
end

-- Restores an entry. Returns the Apply report when bindings were written, else nil.
function Service:restoreEntry(entry)
	local report
	if entry.live then
		self.applying = true
		local diff = Diff.compute(Snapshot.capture(self.api), entry.live, nil)
		local ok, result = pcall(Apply.run, self.api, diff, entry.bindingSet or self:settings().bindingSet)
		self.applying = false
		if not ok then
			error(result, 0)
		end
		report = result
		report.kind = "restore"
	end
	for key, p in pairs(entry.profiles or {}) do
		if p == false then
			self.db.profiles[key] = nil
		else
			self.db.profiles[key] = Util.deepCopy(p)
		end
	end
	if entry.renamed then
		for _, c in pairs(self.db.chars) do
			if c.activeProfile == entry.renamed.to then
				c.activeProfile = entry.renamed.from
			end
		end
	end
	for k, v in pairs(entry.settings or {}) do
		self:settings()[k] = Util.deepCopy(v)
	end
	self.char.activeProfile = entry.activeProfile
	return report
end

-- Writing bindings back into the account set while the addon is configured for the
-- character set needs the FR-015 confirmation.
function Service:needsAccountConfirm(entry)
	return entry.live ~= nil and entry.bindingSet == "account" and self:settings().bindingSet ~= "account"
end

function Service:listHistory()
	local out = {}
	for _, e in ipairs(History.list(self.char)) do
		out[#out + 1] = { id = e.id, at = e.at, op = e.op, profileName = e.profileName }
	end
	return out
end

local function doneWithReport(kind, report)
	local step = { step = "done", kind = kind }
	if report then
		step.report = report
	end
	return step
end

function Service:undo(confirmed)
	if self.readOnly then
		return err("errReadOnly")
	end
	local entry = History.peek(self.char)
	if not entry then
		return err("errNothingToUndo")
	end
	if self:needsAccountConfirm(entry) and not confirmed then
		return { step = "confirmRestoreAccount", action = "undo" }
	end
	if entry.live and self.api.inCombat() then
		return self:defer({ type = "undo", id = entry.id })
	end
	History.pop(self.char)
	local report = self:restoreEntry(entry)
	self:notify("msgUndone", self.L["op_" .. entry.op], entry.profileName or "")
	return doneWithReport("undo", report)
end

function Service:restore(id, confirmed)
	if self.readOnly then
		return err("errReadOnly")
	end
	local entry = History.find(self.char, id)
	if not entry then
		return err("errNoBackup")
	end
	if self:needsAccountConfirm(entry) and not confirmed then
		return { step = "confirmRestoreAccount", action = "restore", id = id }
	end
	if entry.live and self.api.inCombat() then
		return self:defer({ type = "restore", id = id })
	end
	local profiles
	if entry.profiles then
		profiles = {}
		for key in pairs(entry.profiles) do
			profiles[key] = self.db.profiles[key] and Util.deepCopy(self.db.profiles[key]) or false
		end
	end
	self:backup({
		op = "restore",
		profileName = entry.profileName,
		live = entry.live ~= nil,
		profiles = profiles,
		settings = entry.settings ~= nil,
		renamed = entry.renamed and { from = entry.renamed.to, to = entry.renamed.from } or nil,
	})
	local report = self:restoreEntry(entry)
	self:notify("msgRestored", self.L["op_" .. entry.op], entry.profileName or "")
	return doneWithReport("restore", report)
end

-- Combat queue ---------------------------------------------------------------

function Service:defer(op)
	local replaced = self.queue:set(op)
	self.char.combatQueued = { type = op.type, profile = op.name, at = self:now() }
	if replaced then
		self:notify("msgQueuedReplaced")
	else
		self:notify("msgQueued")
	end
	return { step = "queued", op = op }
end

function Service:onCombatEnd()
	local op = self.queue:take()
	if not op then
		return nil
	end
	self.char.combatQueued = nil
	self:notify("msgQueuedRunning")
	if op.type == "apply" then
		local report = self:doApply(op.name, op.opts or {}, "apply")
		return { step = "done", kind = "apply", report = report, name = op.name }
	elseif op.type == "undo" then
		-- Undo exactly the entry the player chose; newer operations may have been
		-- recorded during combat (they do not need the game, so they ran at once).
		local top = History.peek(self.char)
		if top and top.id == op.id then
			return self:undo(true)
		end
		return self:restore(op.id, true)
	elseif op.type == "restore" then
		return self:restore(op.id, true)
	elseif op.type == "modeSwitch" then
		return self:confirmModeSwitch(op.request)
	end
	return nil
end

-- Called once per UI load (first PLAYER_ENTERING_WORLD).
function Service:onLoad()
	if self.readOnly then
		self:notify("warnReadOnly")
		return nil
	end
	if self.char.combatQueued then
		self:notify("msgQueuedCancelled")
		self.char.combatQueued = nil
	end
	local pending = self.char.pending
	if not pending then
		return nil
	end
	self.char.pending = nil
	local profile = self.db.profiles[pending.profile]
	if not profile then
		self:notify("errNoProfileNamed", pending.profile)
		return err("errNoProfile")
	end
	if self:currentMode() ~= pending.expectMode then
		self:notify("msgModeSwitchFailed", profile.name)
		return err("modeMismatch")
	end
	if self.api.inCombat() then
		return self:defer({ type = "apply", name = profile.name, opts = {} })
	end
	local report = self:doApply(profile.name, {}, "apply")
	return { step = "done", kind = "apply", report = report, name = profile.name }
end

-- Profiles -------------------------------------------------------------------

function Service:listProfiles()
	local out = {}
	local activeKey = self.char.activeProfile
	for _, p in ipairs(Store.list(self.db)) do
		local key = Store.normalize(p.name)
		out[#out + 1] = {
			name = p.name,
			key = key,
			mode = p.mode,
			bt4Profile = p.bt4Profile,
			count = Util.count(p.bindings),
			inactiveCount = Util.count(p.inactive),
			createdAt = p.createdAt,
			updatedAt = p.updatedAt,
			active = key == activeKey,
		}
	end
	return out
end

function Service:getProfile(name)
	return Store.get(self.db, name)
end

function Service:activeProfile()
	local key = self.char.activeProfile
	return key and self.db.profiles[key] or nil
end

-- Saves the current bindings (without shared ones) into `name`.
function Service:saveCurrent(name, overwrite)
	if self.readOnly then
		return err("errReadOnly")
	end
	local ok, e = Store.validateName(name)
	if not ok then
		return err(e)
	end
	local existing = Store.get(self.db, name)
	if existing and not overwrite then
		return { step = "confirmOverwrite", action = "save", name = existing.name }
	end
	local groups = self:groups()
	local isCommon = self:isCommonFn(groups)
	local mode = self:currentMode()
	local data = {
		mode = mode,
		bindings = withoutCommon(self:capture(), isCommon),
	}
	if self:settings().rememberBT4Profile and mode == "bt4" then
		data.bt4Profile = self.api.bt4CurrentProfile()
	end
	local key = Store.normalize(name)
	local profile
	if existing then
		self:backup({ op = "overwrite", profileName = existing.name, profiles = { [key] = Util.deepCopy(existing) } })
		profile = Store.overwrite(self.db, name, data, self:now())
	else
		self:backup({ op = "create", profileName = Util.trim(name), profiles = { [key] = false } })
		profile = Store.create(self.db, name, data, self:now())
	end
	self.char.activeProfile = key
	local count = Util.count(profile.bindings)
	self:notify("msgSaved", profile.name, count)
	if Groups.allSelected(groups, self:settings().commonGroups) then
		self:notify("warnAllCommon")
	end
	return { step = "done", kind = "save", name = profile.name, count = count }
end

function Service:rename(oldName, newName)
	if self.readOnly then
		return err("errReadOnly")
	end
	local profile = Store.get(self.db, oldName)
	if not profile then
		return err("errNoProfile")
	end
	local ok, e = Store.validateName(newName)
	if not ok then
		return err(e)
	end
	local oldKey, newKey = Store.normalize(oldName), Store.normalize(newName)
	if oldKey ~= newKey and self.db.profiles[newKey] then
		return err("errNameTaken")
	end
	local profiles = { [oldKey] = Util.deepCopy(profile) }
	if newKey ~= oldKey then
		profiles[newKey] = false
	end
	local previousName = profile.name
	self:backup({ op = "rename", profileName = Util.trim(newName), profiles = profiles,
		renamed = { from = oldKey, to = newKey } })
	Store.rename(self.db, oldName, newName, self:now())
	self:notify("msgRenamed", previousName, Util.trim(newName))
	return { step = "done", kind = "rename", name = Util.trim(newName) }
end

function Service:duplicate(srcName, newName)
	if self.readOnly then
		return err("errReadOnly")
	end
	if not Store.get(self.db, srcName) then
		return err("errNoProfile")
	end
	local ok, e = Store.validateName(newName)
	if not ok then
		return err(e)
	end
	if Store.exists(self.db, newName) then
		return err("errNameTaken")
	end
	self:backup({ op = "duplicate", profileName = Util.trim(newName), profiles = { [Store.normalize(newName)] = false } })
	local profile = Store.duplicate(self.db, srcName, newName, self:now())
	self:notify("msgDuplicated", profile.name)
	return { step = "done", kind = "duplicate", name = profile.name }
end

function Service:delete(name)
	if self.readOnly then
		return err("errReadOnly")
	end
	local profile = Store.get(self.db, name)
	if not profile then
		return err("errNoProfile")
	end
	local key = Store.normalize(name)
	self:backup({ op = "delete", profileName = profile.name, profiles = { [key] = Util.deepCopy(profile) } })
	Store.delete(self.db, name)
	self:notify("msgDeleted", profile.name)
	return { step = "done", kind = "delete", name = profile.name }
end

-- FR-034: edit the mode / Bartender4 profile stored in a profile.
function Service:setProfileMode(name, mode)
	if mode ~= "bt4" and mode ~= "blizzard" then
		return err("errSchema")
	end
	return self:editProfile(name, { mode = mode })
end

function Service:setProfileBT4(name, bt4Profile)
	if bt4Profile == "" then
		bt4Profile = false
	end
	return self:editProfile(name, { bt4Profile = bt4Profile or false })
end

function Service:editProfile(name, fields)
	if self.readOnly then
		return err("errReadOnly")
	end
	local profile = Store.get(self.db, name)
	if not profile then
		return err("errNoProfile")
	end
	self:backup({ op = "edit", profileName = profile.name,
		profiles = { [Store.normalize(name)] = Util.deepCopy(profile) } })
	Store.update(self.db, name, fields, self:now())
	return { step = "done", kind = "edit", name = profile.name }
end

-- Apply ----------------------------------------------------------------------

local function dedupeIssues(list)
	local seen, out = {}, {}
	for _, issue in ipairs(list) do
		local id = issue.key .. "\0" .. issue.reason
		if not seen[id] then
			seen[id] = true
			out[#out + 1] = issue
		end
	end
	return out
end

function Service:bt4SwitchNeeded(profile)
	return profile.mode == "bt4" and profile.bt4Profile ~= nil
		and self:currentMode() == "bt4"
		and self.api.bt4CurrentProfile() ~= profile.bt4Profile
end

-- Issues shown before and after applying (validation + shared-binding conflicts).
function Service:collectIssues(profile, diff, ignoreMode)
	local toCheck = {}
	for key, cmd in pairs(profile.bindings) do
		if not diff.skippedCommon[key] and not diff.conflicts[key] then
			toCheck[key] = cmd
		end
	end
	local issues = Validate.issues(Validate.newContext(self.api), toCheck)
	for _, key in ipairs(Util.sortedKeys(diff.conflicts)) do
		issues[#issues + 1] = { key = key, command = diff.conflicts[key].profile, reason = "commonConflict" }
	end
	if ignoreMode then
		for _, issue in ipairs(Mode.unusable(profile, self:currentMode())) do
			issues[#issues + 1] = issue
		end
	end
	return dedupeIssues(issues)
end

function Service:requestApply(name, opts)
	opts = opts or {}
	if self.readOnly then
		return err("errReadOnly")
	end
	local profile = Store.get(self.db, name)
	if not profile then
		return err("errNoProfile")
	end
	local mode = self:currentMode()
	if not opts.ignoreMode and profile.mode ~= mode then
		return {
			step = "needsModeChoice",
			name = profile.name,
			profileMode = profile.mode,
			currentMode = mode,
			bt4Installed = Mode.bt4Installed(self.api),
			unusable = Mode.unusable(profile, mode),
		}
	end
	return self:preview(profile, opts)
end

function Service:preview(profile, opts)
	opts = opts or {}
	local isCommon = self:isCommonFn()
	local diff = Diff.compute(self:capture(), profile.bindings, isCommon)
	local issues = self:collectIssues(profile, diff, opts.ignoreMode)
	local warnings = {}
	if Util.isEmpty(profile.bindings) then
		warnings[#warnings + 1] = "warnEmptyProfile"
	end
	if opts.ignoreMode then
		warnings[#warnings + 1] = "warnModeMismatch"
	end
	local bt4Switch = self:bt4SwitchNeeded(profile)
	if diff.count == 0 and not bt4Switch then
		self.char.activeProfile = Store.normalize(profile.name)
		self:notify("msgNoChanges", profile.name)
		return { step = "noChanges", name = profile.name }
	end
	return {
		step = "preview",
		name = profile.name,
		diff = diff,
		issues = issues,
		warnings = warnings,
		bt4Switch = bt4Switch and profile.bt4Profile or nil,
		opts = opts,
	}
end

function Service:confirmApply(request)
	if self.readOnly then
		return err("errReadOnly")
	end
	if self.api.inCombat() then
		return self:defer({ type = "apply", name = request.name, opts = request.opts })
	end
	local report = self:doApply(request.name, request.opts or {}, "apply")
	if not report then
		return err("errNoProfile")
	end
	return { step = "done", kind = "apply", report = report, name = request.name }
end

-- Applies a profile now. The caller guarantees no combat (FR-020).
function Service:doApply(name, opts, op)
	local profile = Store.get(self.db, name)
	if not profile then
		self:notify("errNoProfileNamed", tostring(name))
		return nil
	end
	local report = { kind = "apply", changed = 0, issues = {} }
	self:backup({ op = op or "apply", profileName = profile.name, live = true })

	if profile.mode == "bt4" and profile.bt4Profile and self:currentMode() == "bt4"
		and self.api.bt4CurrentProfile() ~= profile.bt4Profile then
		if not self.api.bt4SetProfile(profile.bt4Profile) then
			report.issues[#report.issues + 1] = { key = "", command = profile.bt4Profile, reason = "bt4ProfileMissing" }
		end
	end

	local t0 = self:clock()
	self.applying = true
	local isCommon = self:isCommonFn()
	local diff = Diff.compute(self:capture(), profile.bindings, isCommon)
	local ok, result = pcall(Apply.run, self.api, diff, self:settings().bindingSet)
	self.applying = false
	if not ok then
		self:notify("errApplyFailed", tostring(result))
		return nil
	end
	self.stats.lastApplyMs = self:clock() - t0
	self.stats.lastApplyChanged = result.changed

	report.changed = result.changed
	for _, issue in ipairs(result.issues) do
		report.issues[#report.issues + 1] = issue
	end
	for _, issue in ipairs(self:collectIssues(profile, diff, opts and opts.ignoreMode)) do
		report.issues[#report.issues + 1] = issue
	end
	report.issues = dedupeIssues(report.issues)
	self.char.activeProfile = Store.normalize(profile.name)
	self:notify("msgApplied", profile.name, report.changed, #report.issues)
	return report
end

-- Modes ----------------------------------------------------------------------

function Service:applyWithoutSwitch(request)
	local profile = Store.get(self.db, request.name)
	if not profile then
		return err("errNoProfile")
	end
	return self:preview(profile, { ignoreMode = true })
end

function Service:confirmModeSwitch(request)
	if self.readOnly then
		return err("errReadOnly")
	end
	local profile = Store.get(self.db, request.name)
	if not profile then
		return err("errNoProfile")
	end
	if self.api.inCombat() then
		return self:defer({ type = "modeSwitch", name = profile.name, request = request })
	end
	local target = profile.mode
	if target == "bt4" and not Mode.bt4Installed(self.api) then
		return err("errBT4Missing", { name = profile.name })
	end
	self.char.pending = {
		type = "applyAfterReload",
		profile = Store.normalize(profile.name),
		expectMode = target,
		at = self:now(),
	}
	if not self.api.setAddonEnabled(Mode.BT4, target == "bt4") then
		self.char.pending = nil
		return err("errAddonToggle")
	end
	self.api.reloadUI()
	return { step = "reloading", name = profile.name }
end

-- Manual changes (US3) --------------------------------------------------------

-- A named command this client does not declare (e.g. a binding of a disabled addon).
-- The game refuses such bindings, so they are neither "changed" nor dropped (FR-013).
local function unavailable(cmd, known)
	return Commands.classify(cmd) == "named" and not known[cmd]
end

function Service:dirtyDiff()
	local active = self:activeProfile()
	if not active then
		return nil
	end
	local diff = Diff.compute(self:capture(), active.bindings, self:isCommonFn())
	Diff.without(diff, active.inactive)
	local known = Snapshot.knownCommands(self.api)
	local skip = {}
	for key, cmd in pairs(diff.added) do
		if unavailable(cmd, known) then
			skip[key] = true
		end
	end
	for key, change in pairs(diff.changed) do
		if unavailable(change.to, known) then
			skip[key] = true
		end
	end
	return Diff.without(diff, skip)
end

function Service:dirtyCount()
	local diff = self:dirtyDiff()
	return diff and diff.count or 0
end

function Service:saveToProfile()
	if self.readOnly then
		return err("errReadOnly")
	end
	local active = self:activeProfile()
	if not active then
		return err("errNoActive")
	end
	local bindings = withoutCommon(self:capture(), self:isCommonFn())
	local known = Snapshot.knownCommands(self.api)
	for key, cmd in pairs(active.bindings) do
		if unavailable(cmd, known) then
			bindings[key] = cmd
		end
	end
	local inactive, origin = {}, {}
	for key, cmd in pairs(active.inactive) do
		if bindings[key] == nil then
			inactive[key] = cmd
		end
	end
	for key, cmd in pairs(active.origin) do
		if bindings[key] ~= nil then
			origin[key] = cmd
		end
	end
	self:backup({ op = "saveToProfile", profileName = active.name,
		profiles = { [self.char.activeProfile] = Util.deepCopy(active) } })
	Store.update(self.db, active.name, { bindings = bindings, inactive = inactive, origin = origin }, self:now())
	self:notify("msgSavedToProfile", active.name)
	return { step = "done", kind = "saveToProfile", name = active.name }
end

function Service:revertToProfile()
	local active = self:activeProfile()
	if not active then
		return err("errNoActive")
	end
	return self:requestApply(active.name)
end

-- Shared bindings and settings ------------------------------------------------

function Service:groupsInfo()
	return self:groups(), self:settings().commonGroups
end

function Service:setCommonGroup(key, value)
	if self.readOnly then
		return err("errReadOnly")
	end
	local groups = self:groups()
	local g = groups.byKey[key]
	if not g or not g.selectable then
		return err("errGroupNotSelectable")
	end
	self:settings().commonGroups[key] = value and true or nil
	if Groups.allSelected(groups, self:settings().commonGroups) then
		self:notify("warnAllCommon")
	end
	return { step = "done", kind = "settings" }
end

function Service:setBindingSet(set, confirmed)
	if self.readOnly then
		return err("errReadOnly")
	end
	if set ~= "character" and set ~= "account" then
		return err("errSchema")
	end
	if self:settings().bindingSet == set then
		return { step = "done", kind = "settings" }
	end
	if set == "account" and not confirmed then
		return { step = "confirmAccountSet" }
	end
	self:backup({ op = "setChange", settings = true })
	self:settings().bindingSet = set
	if set == "account" then
		self:settings().accountSetAcknowledged = true
	end
	self:notify("msgBindingSet", self.L["set_" .. set])
	return { step = "done", kind = "settings" }
end

function Service:setRememberBT4(value)
	if self.readOnly then
		return err("errReadOnly")
	end
	self:settings().rememberBT4Profile = value and true or false
	return { step = "done", kind = "settings" }
end

-- Conversion (US6) -----------------------------------------------------------

function Service:defaultConvertName(name, targetMode)
	local suffix = " (" .. self.L["mode_" .. targetMode] .. ")"
	local base = Util.utf8truncate(Util.trim(name), Store.MAX_NAME - Util.utf8len(suffix))
	return base .. suffix
end

function Service:convert(name, targetMode, newName, overwrite)
	if self.readOnly then
		return err("errReadOnly")
	end
	local profile = Store.get(self.db, name)
	if not profile then
		return err("errNoProfile")
	end
	if targetMode ~= "bt4" and targetMode ~= "blizzard" then
		targetMode = profile.mode == "bt4" and "blizzard" or "bt4"
	end
	if profile.mode == targetMode then
		return err("errSameMode")
	end
	newName = newName or self:defaultConvertName(profile.name, targetMode)
	local ok, e = Store.validateName(newName)
	if not ok then
		return err(e)
	end
	local existing = Store.get(self.db, newName)
	if existing and not overwrite then
		return { step = "confirmOverwrite", action = "convert", name = existing.name,
			source = profile.name, targetMode = targetMode }
	end
	local data, report = Convert.convert(profile, targetMode)
	local key = Store.normalize(newName)
	self:backup({ op = "convert", profileName = Util.trim(newName),
		profiles = { [key] = existing and Util.deepCopy(existing) or false } })
	local created
	if existing then
		created = Store.overwrite(self.db, newName, data, self:now())
	else
		created = Store.create(self.db, newName, data, self:now())
	end
	report.kind = "convert"
	self:notify("msgConverted", profile.name, created.name, #report.issues)
	return { step = "done", kind = "convert", name = created.name, report = report }
end

-- Import / export (US7) --------------------------------------------------------

function Service:exportProfile(name)
	local profile = Store.get(self.db, name)
	if not profile then
		return err("errNoProfile")
	end
	return { step = "export", name = profile.name, text = self.codec:encode(profile) }
end

function Service:previewImport(text)
	if self.readOnly then
		return err("errReadOnly")
	end
	local data, e = self.codec:decode(text)
	if not data then
		return err(e)
	end
	return {
		step = "importPreview",
		data = data,
		summary = {
			name = data.name,
			mode = data.mode,
			count = Util.count(data.bindings),
			inactiveCount = Util.count(data.inactive),
		},
		nameTaken = Store.exists(self.db, data.name),
	}
end

-- opts = { newName?, replace? }
function Service:confirmImport(request, opts)
	opts = opts or {}
	if self.readOnly then
		return err("errReadOnly")
	end
	local name = opts.newName or request.data.name
	local ok, e = Store.validateName(name)
	if not ok then
		return err(e)
	end
	local existing = Store.get(self.db, name)
	if existing and not opts.replace then
		return { step = "confirmImportName", name = existing.name, request = request }
	end
	local key = Store.normalize(name)
	local profile
	if existing then
		self:backup({ op = "importReplace", profileName = existing.name, profiles = { [key] = Util.deepCopy(existing) } })
		profile = Store.overwrite(self.db, name, request.data, self:now())
	else
		self:backup({ op = "import", profileName = Util.trim(name), profiles = { [key] = false } })
		profile = Store.create(self.db, name, request.data, self:now())
	end
	self:notify("msgImported", profile.name, Util.count(profile.bindings))
	return { step = "done", kind = "import", name = profile.name }
end

-- Status and diagnostics ---------------------------------------------------------

function Service:status()
	local active = self:activeProfile()
	return {
		mode = self:currentMode(),
		active = active and active.name or nil,
		dirty = active and self:dirtyCount() or 0,
		bindingSet = self:settings().bindingSet,
		readOnly = self.readOnly,
		bt4Installed = Mode.bt4Installed(self.api),
		bt4Loaded = self:currentMode() == "bt4",
	}
end

function Service:diag()
	self:capture()
	return {
		mode = self:currentMode(),
		clientSet = self.api.currentBindingSet(),
		configuredSet = self:settings().bindingSet,
		keys = self.stats.keys,
		captureMs = self.stats.captureMs,
		lastApplyMs = self.stats.lastApplyMs,
		lastApplyChanged = self.stats.lastApplyChanged,
		profiles = Util.count(self.db.profiles),
		history = #self.char.history,
		readOnly = self.readOnly,
	}
end
