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
		return
	end

	self.value = value
	self.sender = coroutine.running()
	self.hub:_coyield()
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
		self.hub.ready:push({co})
		return value
	end

	self.recver = coroutine.running()
	return self.hub:_coyield()
end


function Pipe_mt:close()
	self.closed = true
end


local function Pipe(hub)
	local self = setmetatable({hub=hub}, Pipe_mt)
	return self
end


return {
	Pipe = Pipe,
}


