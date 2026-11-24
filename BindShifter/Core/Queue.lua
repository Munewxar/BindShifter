-- Deferred operation while in combat (FR-020, FR-021). The newest request wins.
local _, ns = ...

local Queue = {}
ns.Queue = Queue
Queue.__index = Queue

function Queue.new()
	return setmetatable({ op = nil }, Queue)
end

-- Stores `op`; returns the operation it replaced, if any.
function Queue:set(op)
	local previous = self.op
	self.op = op
	return previous
end

function Queue:take()
	local op = self.op
	self.op = nil
	return op
end

function Queue:peek()
	return self.op
end
