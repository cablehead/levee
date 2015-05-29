local ffi = require("ffi")
local C = ffi.C

local Heap = require("levee.heap")


local Scheduler_mt = {}
Scheduler_mt.__index = Scheduler_mt

function Scheduler_mt:now()
	C.gettimeofday(self.tv, nil)
	return (self.tv.tv_sec * 1000LL) + (self.tv.tv_usec / 1000LL)
end

function Scheduler_mt:add(ms, co)
	C.gettimeofday(self.tv, nil)
	self.heap:push(self:now() + ms, co)
end

function Scheduler_mt:peek()
	return self.heap:peek()
end

function Scheduler_mt:pop()
	return self.heap:pop()
end

function Scheduler()
	return setmetatable(
		{heap=Heap(), tv=ffi.new("struct timeval")}, Scheduler_mt)
end

return Scheduler
