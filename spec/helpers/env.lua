-- Builds a Service on top of the fake adapter for flow tests.
local loader = require("loader")
local FakeWow = require("fake_wow")

local M = {}

function M.new(opts)
	opts = opts or {}
	local ns = loader.loadCore()
	local fake = FakeWow.new(opts)
	local db = ns.Migrations.run(opts.db, 1)
	local notes = {}
	local codec
	if opts.codec then
		local serializer, deflate = loader.codecLibs()
		codec = ns.Codec.new({ serializer = serializer, deflate = deflate })
	end
	local service = ns.Service.new({
		api = fake.api,
		db = db,
		codec = codec,
		readOnly = opts.readOnly,
		notify = function(key, ...)
			notes[#notes + 1] = { key = key, args = { ... } }
		end,
	})
	local env = { ns = ns, fake = fake, api = fake.api, db = db, service = service, notes = notes }

	function env.noted(key)
		for _, n in ipairs(notes) do
			if n.key == key then
				return n
			end
		end
		return nil
	end

	-- Advances the fake clock so history entries get distinct timestamps.
	function env.tick(seconds)
		fake.state.time = fake.state.time + (seconds or 1)
	end

	-- Re-creates the Service after a simulated UI reload, keeping the database.
	function env.reload()
		fake.simulateReload()
		env.service = ns.Service.new({
			api = fake.api,
			db = db,
			codec = codec,
			notify = function(key, ...)
				notes[#notes + 1] = { key = key, args = { ... } }
			end,
		})
		return env.service
	end

	return env
end

return M
