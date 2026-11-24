-- Loads addon files the way the WoW client does: each file receives (addonName, ns).
local M = {}

local ROOT = "BindShifter/"

local function tocFiles()
	local files = {}
	for line in io.lines(ROOT .. "BindShifter.toc") do
		line = line:gsub("\r", "")
		if line:match("%.lua$") then
			files[#files + 1] = (line:gsub("\\", "/"))
		end
	end
	return files
end
M.tocFiles = tocFiles

function M.load(paths, ns)
	ns = ns or {}
	for _, path in ipairs(paths) do
		local chunk = assert(loadfile(ROOT .. path))
		chunk("BindShifter", ns)
	end
	return ns
end

-- Locales and Core modules in TOC order.
function M.loadCore(ns)
	local list = {}
	for _, file in ipairs(tocFiles()) do
		if file:match("^Core/") or file:match("^Locales/") then
			list[#list + 1] = file
		end
	end
	return M.load(list, ns)
end

local LIBS = {
	LibStub = "Libs/LibStub/LibStub.lua",
	["AceSerializer-3.0"] = "Libs/AceSerializer-3.0/AceSerializer-3.0.lua",
	LibDeflate = "Libs/LibDeflate/LibDeflate.lua",
	["CallbackHandler-1.0"] = "Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua",
	["AceConfigRegistry-3.0"] = "Libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua",
}

-- WoW exposes string/table helpers as globals; embedded libraries rely on them.
local function wowShims()
	strmatch = strmatch or string.match
	strfind = strfind or string.find
	strsub = strsub or string.sub
	strlen = strlen or string.len
	strbyte = strbyte or string.byte
	strchar = strchar or string.char
	strrep = strrep or string.rep
	format = format or string.format
	gsub = gsub or string.gsub
	tinsert = tinsert or table.insert
	tremove = tremove or table.remove
	wipe = wipe or function(t)
		for k in pairs(t) do
			t[k] = nil
		end
		return t
	end
end

-- Loads embedded libraries into the global environment (LibStub is global in WoW).
function M.loadLibs(names)
	wowShims()
	for _, name in ipairs(names) do
		if name == "LibStub" then
			LibStub = nil -- a stub from another test must not shadow the real library
		end
		local chunk = assert(loadfile(ROOT .. assert(LIBS[name], name)))
		chunk()
	end
end

-- Real AceSerializer + LibDeflate pair for Codec tests.
function M.codecLibs()
	M.loadLibs({ "LibStub", "AceSerializer-3.0", "LibDeflate" })
	return LibStub("AceSerializer-3.0"), LibStub("LibDeflate")
end

return M
