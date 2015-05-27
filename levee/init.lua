local message = require("levee.message")
local refs = require("levee.refs")
local task = require("levee.task")
local FIFO = require("levee.fifo")

local Poller = require("levee.poller")


local Hub = {}
Hub.__index = Hub


function Hub:new()
	local hub = {}
	setmetatable(hub, self)

	hub.id = refs.new(hub)

	hub.ready = FIFO()

	hub.registered = {}
	hub.poller = Poller()

	hub.io = require("levee.io")(hub)
	hub.tcp = require("levee.tcp")(hub)
	hub.http = require("levee.http")(hub)
	return hub
end


function Hub:register(no, r, w)
	self.poller:register(no, r, w)

	local slots = {false, false}

	if r then
		slots[1], r = unpack(self:switch(true))
	end

	if w then
		slots[2], w = unpack(self:switch(true))
	end

	self.registered[no] = slots
	return r, w
end


function Hub:unregister(no)
	self.poller:unregister(no, self.registered[1], self.registered[2])
	self.registered[no] = nil
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

		-- TODO: move into poller
		local POLLIN = 1
		local POLLOUT = 2
		local POLLERR = 3

		local id, event, flags = self.poller:poll()

		-- print(string.format("id=%d, event=%d", id, event), flags)

		local poll = self.registered[id]

		if event == POLLERR then
			if poll[1] then poll[1]:close() end
			if poll[2] then poll[2]:close() end
		else
			poll[event]:send(true)
		end
	end

	print("peace")
end


local keep = {}

function Hub:spawn(f, ...)
	-- self.ready:push({co=coroutine.create(f), a={...}})
	-- if true then return end
	-- TODO: we probably need to keep a handle on co
	local co = coroutine.create(f)
	table.insert(keep, co)
	self.ready:push({co=co, a={...}})
end

function Hub:resume(co, ...)
	self.ready:push({co=co, a={...}})
end

function Hub:pause(m)
	self:resume(coroutine.running())
	coroutine.yield()
end

function Hub:pipe()
	return message.Pipe(self)
end

function Hub:switch(clear_on_recv)
	return message.Switch(self, clear_on_recv)
end


function run(f)
	local h = Hub:new()
	h:spawn(f, h)
	h:main()
end


return {run=run}
