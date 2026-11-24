local loader = require("loader")

describe("Codec", function()
	local ns, codec, serializer, deflate
	before_each(function()
		ns = loader.loadCore()
		serializer, deflate = loader.codecLibs()
		codec = ns.Codec.new({ serializer = serializer, deflate = deflate })
	end)

	local profile = {
		name = "Рейд ICC",
		mode = "bt4",
		bt4Profile = "Main",
		bindings = { ["SHIFT-1"] = "CLICK BT4Button25:LeftButton", ["|"] = "SPELL Weird|Name", Q = "MACRO Burst" },
		inactive = { E = "CLICK BT4Button13:LeftButton" },
		origin = {},
		createdAt = 5,
		updatedAt = 6,
	}

	it("round-trips a profile (SC-006)", function()
		local text = codec:encode(profile)
		assert.equal("BSH1:", text:sub(1, 5))
		assert.is_nil(text:find("|", 1, true))
		local data = codec:decode(text)
		assert.same({ name = profile.name, mode = profile.mode, bt4Profile = profile.bt4Profile,
			bindings = profile.bindings, inactive = profile.inactive, origin = {} }, data)
	end)

	it("contains no personal data or dates", function()
		local serialized = deflate:DecompressDeflate(deflate:DecodeForPrint(codec:encode(profile):sub(6)))
		local _, data = serializer:Deserialize(serialized)
		assert.same({ "bindings", "bt4Profile", "inactive", "mode", "name", "origin" }, ns.Util.sortedKeys(data.profile))
	end)

	it("ignores whitespace inserted by copy and paste", function()
		local text = codec:encode(profile)
		local spaced = "  " .. text:sub(1, 20) .. "\n " .. text:sub(21) .. "\n"
		assert.equal(profile.name, codec:decode(spaced).name)
	end)

	it("reports each failure step", function()
		local text = codec:encode(profile)
		assert.same({ nil, "errPrefix" }, { codec:decode("hello") })
		assert.same({ nil, "errDecode" }, { codec:decode("BSH1:!!!") })
		assert.same({ nil, "errDecompress" }, { codec:decode("BSH1:" .. deflate:EncodeForPrint("not deflate")) })
		local function wrap(data)
			return "BSH1:" .. deflate:EncodeForPrint(deflate:CompressDeflate(serializer:Serialize(data)))
		end
		assert.same({ nil, "errDeserialize" },
			{ codec:decode("BSH1:" .. deflate:EncodeForPrint(deflate:CompressDeflate("garbage"))) })
		assert.same({ nil, "errSchema" }, { codec:decode(wrap({ kind = "other", formatVersion = 1, profile = {} })) })
		assert.same({ nil, "errNewerVersion" }, { codec:decode(wrap({ kind = "profile", formatVersion = 99, profile = {} })) })
		assert.same({ nil, "errSchema" }, { codec:decode(wrap({ kind = "profile", formatVersion = 1,
			profile = { name = "", mode = "bt4", bindings = {} } })) })
		assert.same({ nil, "errSchema" }, { codec:decode(wrap({ kind = "profile", formatVersion = 1,
			profile = { name = "A", mode = "weird", bindings = {} } })) })
		assert.same({ nil, "errSchema" }, { codec:decode(wrap({ kind = "profile", formatVersion = 1,
			profile = { name = "A", mode = "bt4", bindings = { ["1"] = 5 } } })) })
		assert.same({ nil, "errDecompress" }, { codec:decode(text:sub(1, #text - 10)) })
	end)

	it("migrates older formats", function()
		ns.Codec.FORMAT_VERSION = 2
		ns.Codec.formatMigrations[1] = function(data)
			data.profile.migrated = true
		end
		local text = "BSH1:" .. deflate:EncodeForPrint(deflate:CompressDeflate(serializer:Serialize({
			kind = "profile", formatVersion = 1, profile = { name = "Old", mode = "blizzard", bindings = {} } })))
		local data = codec:decode(text)
		assert.equal("Old", data.name)
	end)
end)
