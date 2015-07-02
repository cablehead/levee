local FIFO = require("levee.fifo")


--
-- Pipe

-- A pipe has exactly one Sender and one Recver.
--

local Pipe_mt = {}
Pipe_mt.__index = Pipe_mt


function Pipe_mt:send(value)
	assert(not self.sender)

	if self.closed then
		return
	end

	if self.recver then
		local co = self.recver
		self.recver = nil
		self.hub.ready:push({co, value})
		self.hub:continue()
		return true
	end

	self.value = value
	self.sender = coroutine.running()
	return self.hub:_coyield()
end


function Pipe_mt:recv()
	assert(not self.recver)

	if self.closed then
		return
	end

	if self.value then
		local value = self.value
		self.value = nil
		local co = self.sender
		self.sender = nil
		self.hub.ready:push({co, true})
		return value
	end

	self.recver = coroutine.running()
	return self.hub:_coyield()
end


function Pipe_mt:__call()
	return self:recv()
end


function Pipe_mt:close()
	if self.closed then
		return
	end

	self.closed = true

	if self.recver then
		local co = self.recver
		self.recver = nil
		self.hub.ready:push({co})
	elseif self.sender then
		local co = self.sender
		self.sender = nil
		self.hub.ready:push({co})
	end

	self.hub:continue()
	return true
end


local function Pipe(hub)
	local self = setmetatable({hub=hub}, Pipe_mt)
	return self
end


--
-- Queue

-- A queue is exactly one Sender and one Recver with a fifo in between. Sends
-- won't block until the fifo is filled.

local Queue_mt = {}
Queue_mt.__index = Queue_mt


function Queue_mt:send(value)
	assert(not self.sender)

	if self.closed then
		return
	end

	if self.recver then
		local co = self.recver
		self.recver = nil
		self.hub.ready:push({co, value})
		return true
	end

	if not self.size or #self.fifo < self.size then
		self.fifo:push(value)
		return true
	end

	self.fifo:push(value)
	self.sender = coroutine.running()
  return self.hub:_coyield()
end


function Queue_mt:recv()
	assert(not self.recver)

	if self.sender then
		local co = self.sender
		self.sender = nil
		self.hub.ready:push({co, true})
	end

	if #self.fifo > 0 then
		return self.fifo:pop()
	end

	if self.closed then
		return
	end

	self.recver = coroutine.running()
	return self.hub:_coyield()
end


function Queue_mt:__call()
	return self:recv()
end


function Queue_mt:close()
	if self.closed then
		return
	end

	self.closed = true

	-- TODO: these 1st two conditions need tests
	if self.recver then
		local co = self.recver
		self.recver = nil
		self.hub.ready:push({co})
	elseif self.sender then
		local co = self.sender
		self.sender = nil
		self.hub.ready:push({co})

	elseif #self.fifo > 0 then
		self.fifo:push(nil)
	end
end


local function Queue(hub, size)
	local self = setmetatable({hub=hub, size=size, fifo=FIFO(), }, Queue_mt)
	return self
end


----

return {
	Pipe = Pipe,
	Queue = Queue,
	}
