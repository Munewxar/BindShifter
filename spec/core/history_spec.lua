local loader = require("loader")

describe("History", function()
	local History, char
	before_each(function()
		History = loader.loadCore().History
		char = { history = {}, nextHistoryId = 1 }
	end)

	it("assigns ids and timestamps", function()
		local e = History.push(char, { op = "apply" }, 50)
		assert.equal(1, e.id)
		assert.equal(50, e.at)
		assert.equal(2, History.push(char, { op = "delete" }, 51).id)
	end)

	it("keeps the newest 20 entries", function()
		for i = 1, 25 do
			History.push(char, { op = "apply", n = i }, i)
		end
		assert.equal(20, #char.history)
		assert.equal(6, char.history[1].n)
		assert.equal(25, History.peek(char).n)
	end)

	it("pops, finds and lists newest first", function()
		History.push(char, { op = "a" }, 1)
		History.push(char, { op = "b" }, 2)
		assert.equal("b", History.list(char)[1].op)
		assert.equal("a", History.find(char, 1).op)
		assert.equal("b", History.pop(char).op)
		assert.equal(1, #char.history)
	end)
end)
