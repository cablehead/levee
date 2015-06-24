--
-- Pipe
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
		self.hub:continue()
		return true
	end

	if self.sender then
		local co = self.sender
		self.sender = nil
		self.hub.ready:push({co})
		return true
	end
end


local function Pipe(hub)
	local self = setmetatable({hub=hub}, Pipe_mt)
	return self
end


--
-- Baton
--
local Baton_mt = {}
Baton_mt.__index = Baton_mt


function Baton_mt:resume()
	assert(self.co)
	local co = self.co
	self.co = nil
	self.hub.ready:push({co})
end


function Baton_mt:swap()
	assert(self.co)
	local co = self.co
	self.co = coroutine.running()
	self.hub.ready:push({co})
	return self.hub:_coyield()
end


function Baton_mt:wait()
	assert(not self.co)
	self.co = coroutine.running()
	return self.hub:_coyield()
end


local function Baton(hub)
	local self = setmetatable({hub=hub}, Baton_mt)
	return self
end


return {
	Pipe = Pipe,
	Baton = Baton,
	}
