local message = require("ev.message")


local ffi = require("ffi")


local types = {
	OSX     = "ev.cdef.kqueue",
	Linux   = "ev.cdef.epoll",
	BSD     = "ev.cdef.kqueue"
}
-- return require(types[ffi.os])


local FIFO = {}


function FIFO:new(hub)
	local T = {head = 1, tail = 0}
	setmetatable(T, self)
	self.__index = self
	return T
end


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



local Hub = {}


function Hub:new()
	local hub = {}
	setmetatable(hub, self)
	self.__index = self

	-- hub.tcp = require("ev.tcp")(self)

	hub.ready = FIFO:new()

	hub.loop = coroutine.create(Hub.main)
	coroutine.resume(hub.loop, hub)
	return hub
end


function Hub:main()
	coroutine.yield()
	print("main", self)
	local task = self.ready:pop()

	if type(task) == "function" then
		local co = coroutine.create(task)
		coroutine.resume(co)
	end
	print("peace")
end


function Hub:spawn(f)
	self.ready:push(f)
end


function Hub:pause()
	coroutine.resume(self.loop)
end


function Hub:pipe()
	return message.Pipe:new(self)
end


return {Hub = Hub, FIFO = FIFO}
