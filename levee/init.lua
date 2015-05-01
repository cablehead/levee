local message = require("levee.message")


local ffi = require("ffi")

local Poller = require("levee.poller." .. ffi.os:lower())


-- TODO: need a decent structure here
local FIFO = {}
FIFO.__index = FIFO


function FIFO:new(hub)
	local T = {head = 1, tail = 0}
	setmetatable(T, self)
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

function FIFO:length()
	return self.tail - self.head + 1
end


local Hub = {}
Hub.__index = Hub


function Hub:new()
	local hub = {}
	setmetatable(hub, self)

	hub.ready = FIFO:new()

	hub.registered = {}
	hub.poller = Poller:new()

	hub.tcp = require("levee.tcp")(hub)
	return hub
end


function Hub:register(no)
	local pipe = self:pipe()
	self.poller:register(no)
	self.registered[no] = pipe
	return pipe
end


function Hub:main()

	while true do

		while self.ready:length() > 0 do
			local task = self.ready:pop()
			local status, message = coroutine.resume(task.co, unpack(task.a))
			if not status then
				error(message)
		  end
		end

		if not next(self.registered) then
			return -- fin
			-- error("deadlocked")
		end

		local id, avail = self.poller:poll()
		print(string.format("id=%d, size=%d", id, tonumber(avail)))

		self:spawn(function(p)
			p:send(true)
		end, self.registered[id])
	end

	print("peace")
end


function Hub:spawn(f, ...)
	self.ready:push({co=coroutine.create(f), a={...}})
end


function Hub:resume(co, ...)
	self.ready:push({co=co, a={...}})
end


function Hub:pipe()
	return message.Pipe(self)
end


function run(f)
	local h = Hub:new()
	h:spawn(f, h)
	h:main()
end


return {run=run}
