-- TODO: need a decent structure here
local FIFO = {}
FIFO.__index = FIFO


function FIFO:push(v)
	self.tail = self.tail + 1
	self[self.tail] = v
end


function FIFO:pop()
	local head, tail = self.head, self.tail
	if head > tail then error("empty") end
	local v = self[head]
	self[head] = nil
	self.head = head + 1
	return v
end


function FIFO:__len()
	return self.tail - self.head + 1
end


return function()
	return setmetatable({head = 1, tail = 0}, FIFO)
end
