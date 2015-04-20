

local Pipe = {}


function Pipe:new(hub)
	local T = {hub = hub, closed = false}
	setmetatable(T, self)
	self.__index = self
	return T
end


function Pipe:__call()
	return self:recv()
end


function Pipe:send(data)
	if self.closed then
		return
	end

	local ready
	if self.ready then
		ready = self.ready
		self.ready = nil
	else
		self.ready = coroutine.running()
		ready = self.hub:pause()
	end
	self.hub:switch_to(ready, data)
	return true
end


function Pipe:recv()
	if self.closed then
		return
	end

	if self.ready then
		local ready = self.ready
		self.ready = nil
		return self.hub:pause_to(ready)
	else
		self.ready = coroutine.running()
		return self.hub:pause()
	end
end


function Pipe:close()
	if self.ready then
		self:send(nil)
	end
	self.closed = true
end


return {Pipe = Pipe}
