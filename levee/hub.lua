local sys = require("levee.sys")
local Scheduler = require("levee.scheduler")
local FIFO = require("levee.fifo")
local message = require("levee.message")



local State_mt = {}
State_mt.__index = State_mt


function State_mt:recv()
	if self.value then
		local value = self.value
		self.value = nil
		return value
	end

	self.co = coroutine.running()
	return self.hub:_coyield()
end


function State_mt:set(err)
	local value = err and -1 or 1

	if not self.co then
		self.value = value
		return
	end

	local co = self.co
	self.co = nil
	self.hub:_coresume(co, value)
end


function State_mt:__call(value)
	return self:recv()
end


local function State(hub)
	local self = setmetatable({hub=hub}, State_mt)
	return self
end



local Hub_mt = {}
Hub_mt.__index = Hub_mt


function Hub_mt:pipe()
	return message.Pipe(self)
end


function Hub_mt:_coresume(co, value)
	if co ~= self.parent then
		local status, message = coroutine.resume(co, value)
		if not status then
			error(message)
		end
		return message
	end

	return coroutine.yield(value)
end


function Hub_mt:_coyield()
	if coroutine.running() ~= self.parent then return coroutine.yield() end

	local status, message = coroutine.resume(self.loop)
	if not status then
		error(message)
	end
	return message
end


function Hub_mt:spawn(f, a)
	local co = coroutine.create(f)
	self.ready:push({co, a})
end


function Hub_mt:spawn_later(ms, f, a)
	local co = coroutine.create(f)
	self.scheduled:add(ms, co)
end


function Hub_mt:sleep(ms)
	self.scheduled:add(ms, coroutine.running())
	self:_coyield()
end


function Hub_mt:register(no, r, w)
	local r_ev = r and State(self)
	local w_ev = w and State(self)
	self.registered[no] = {r_ev, w_ev}
	self.poller:register(no, r, w)
	return r_ev, w_ev
end


function Hub_mt:unregister(no, r, w)
	self.poller:unregister(no, r, w)
	local r = self.registered[no]
	if r then
		if r[1] then r[1]:set(true) end
		if r[2] then r[2]:set(true) end
		self.registered[no] = nil
	end
end


function Hub_mt:pump()
	for work in self.ready:popiter() do
		self:_coresume(work[1], work[2])
	end

	local events, n = self.poller:poll(self.scheduled:peek())

	if n == 0 then
		local ms, co = self.scheduled:pop()
		self:_coresume(co)
	end

	for i = 0, n - 1 do
		local no, r_ev, w_ev, e_ev = events[i]:value()
		local r = self.registered[no]
		if r then
			if r_ev then 
				-- self.stats.poll_r = self.stats.poll_r + 1
				r[1]:set(e_ev)
			end
			if w_ev then
				-- self.stats.poll_w = self.stats.poll_w + 1
				r[2]:set(e_ev)
			end
		end
	end
end


function Hub_mt:main()
	while true do
		self:pump()
	end
end


local function Hub()
	local self = setmetatable({}, Hub_mt)

	self.ready = FIFO()
	self.scheduled = Scheduler()
	self.registered = {}
	self.poller = sys.poller()

	self.parent = coroutine.running()
	self.loop = coroutine.create(function() self:main() end)

	self.io = require("levee.io")(self)
	self.tcp = require("levee.tcp")(self)
	self.http = require("levee.http").__plugin(self)

	return self
end


return Hub
