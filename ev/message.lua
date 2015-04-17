

local Pipe = {}


function Pipe:new(hub)
	local T = {hub = hub}
	setmetatable(T, self)
	self.__index = self
	return T
end


function Pipe:send(data)
end


function Pipe:recv()
	self.hub:pause()
end

return {Pipe = Pipe}
