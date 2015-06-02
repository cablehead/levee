local Pipe_mt = {}
Pipe_mt.__index = Pipe_mt


function Pipe_mt:send(value)
	if self.co then
		local co = self.co
		self.co = nil
		self.hub.ready:push({co, value})
		return
	end

	self.value = value
	self.co = coroutine.running()
	self.hub:yield()
end


function Pipe_mt:recv()
	if self.value then
		local value = self.value
		self.value = nil
		local co = self.co
		self.co = nil
		self.hub.ready:push({co, value})
		return value
	end

	self.co = coroutine.running()
	return self.hub:yield()
end


local function Pipe(hub)
	local self = setmetatable({hub=hub}, Pipe_mt)
	return self
end


return {
	Pipe = Pipe,
}


