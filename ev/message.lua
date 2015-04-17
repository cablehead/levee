

local Pipe = {}


function Pipe:new(hub)
	local T = {hub = hub}
	setmetatable(T, self)
	self.__index = self
	return T
end


function Pipe:send(data)
	local ready
	if self.ready then
		ready = self.ready
		self.ready = nil
	else
		self.ready = coroutine.running()
		ready = self.hub:pause()
	end
	self.hub:switch_to(ready, data)
end


function Pipe:recv()
	if self.ready then
		local ready = self.ready
		self.ready = nil
		return self.hub:pause_to(ready)
	else
		self.ready = coroutine.running()
		return self.hub:pause()
	end
end


return {Pipe = Pipe}
