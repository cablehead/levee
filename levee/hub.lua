local sys = require("levee.sys")
local Scheduler = require("levee.scheduler")


local Hub_mt = {}
Hub_mt.__index = Hub_mt

function Hub_mt:spawn(f, a)
	local co = coroutine.create(f)
	coroutine.resume(co, a)
end

function Hub_mt:sleep(ms)
	self.scheduled:add(ms, coroutine.running())
	coroutine.yield()
end

function Hub_mt:register(no, f, r, w)
	local co = coroutine.create(f)
	self.registered[no] = co
	coroutine.resume(co, self, no)
	self.poller:register(no, r, w)
end

function Hub_mt:unregister(no, r, w)
	self.poller:unregister(no, r, w)
	self.registered[no] = nil
end

function Hub_mt:loop()
	local events, n = self.poller:poll(self.scheduled:peek())

	if n == 0 then
		local ms, co = self.scheduled:pop()
		coroutine.resume(co)
	end

	for i = 0, n - 1 do
		local no, r_ev, w_ev, e_ev = events[i]:value()
		if self.registered[no] then
			local status, message = coroutine.resume(
				self.registered[no], r_ev, w_ev, e_ev)
			if not status then
				error(message)
			end
		end
	end
end

local function Hub()
	local self = setmetatable({}, Hub_mt)
	self.scheduled = Scheduler()
	self.poller = sys.poller()
	self.registered = {}
	return self
end

return Hub
