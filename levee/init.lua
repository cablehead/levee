local ffi = require("ffi")

local message = require("levee.message")
local refs = require("levee.refs")
local task = require("levee.task")
local FIFO = require("levee.fifo")

local Poller = require("levee.poller." .. ffi.os:lower())


local Hub = {}
Hub.__index = Hub


function Hub:new()
	local hub = {}
	setmetatable(hub, self)

	hub.id = refs.new(hub)

	hub.ready = FIFO()

	hub.registered = {}
	hub.poller = Poller()

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

		for work in self.ready:popiter() do
			local status, message
			if type(work.co) == "thread" then
				status, message = coroutine.resume(work.co, unpack(work.a))
			else
				status, message = task.resume(work.co, unpack(work.a))
			end

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

		-- TODO: can we get rid of this spawn?
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
