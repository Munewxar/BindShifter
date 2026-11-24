-- Full binding snapshot (research.md R3, FR-001). Returns data-model.md BindingMap.
local _, ns = ...

local Snapshot = {}
ns.Snapshot = Snapshot

local Keys, Commands = ns.Keys, ns.Commands

-- Commands that Bartender4 declares in its Bindings.xml. They are probed explicitly
-- because GetBinding() does not list them while Bartender4 is disabled.
local EXTRA = {}
for i = 1, 120 do
	EXTRA[#EXTRA + 1] = "CLICK BT4Button" .. i .. ":LeftButton"
end
for i = 1, 10 do
	EXTRA[#EXTRA + 1] = "CLICK BT4PetButton" .. i .. ":LeftButton"
	EXTRA[#EXTRA + 1] = "CLICK BT4StanceButton" .. i .. ":LeftButton"
end
Snapshot.EXTRA_COMMANDS = EXTRA

function Snapshot.capture(api)
	local map = {}

	-- 1. Every known key with every modifier combination.
	for _, key in ipairs(Keys.allKeys()) do
		local cmd = Commands.normalize(api.getBindingAction(key))
		if cmd then
			map[key] = cmd
		end
	end

	-- 2 and 3. Keys of every declared command, which also finds exotic keys.
	local function addKeysOf(cmd)
		local keys = api.getBindingKeys(cmd)
		for i = 1, #(keys or {}) do
			local key = Keys.normalize(keys[i])
			if key and map[key] == nil then
				map[key] = cmd
			end
		end
	end
	for _, row in ipairs(api.listBindingCommands()) do
		if not row.header then
			addKeysOf(row.command)
		end
	end
	for _, cmd in ipairs(EXTRA) do
		addKeysOf(cmd)
	end

	return map
end

-- Set of commands the client declares (non-header rows of GetBinding).
function Snapshot.knownCommands(api)
	local set = {}
	for _, row in ipairs(api.listBindingCommands()) do
		if not row.header then
			set[row.command] = true
		end
	end
	return set
end
