local sys = require("levee.sys")
local Scheduler = require("levee.scheduler")
local FIFO = require("levee.fifo")


local Hub_mt = {}
Hub_mt.__index = Hub_mt


function Hub_mt:resume(co)
	if co ~= self.parent then
		local status, message = coroutine.resume(co)
		if not status then
			error(message)
		end
		return message
	end

	return coroutine.yield()
end


function Hub_mt:yield()
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


function Hub_mt:sleep(ms)
	self.scheduled:add(ms, coroutine.running())
	self:yield()
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


function Hub_mt:pump()
	for work in self.ready:popiter() do
		self:resume(work[1])
	end

	local events, n = self.poller:poll(self.scheduled:peek())

	if n == 0 then
		local ms, co = self.scheduled:pop()
		self:resume(co)
	end

	for i = 0, n - 1 do
		local no, r_ev, w_ev, e_ev = events[i]:value()
		if self.registered[no] then
			self:resume(self.registered[no])
			--[[
			local status, message = coroutine.resume(
				self.registered[no], r_ev, w_ev, e_ev)
			if not status then
				error(message)
			end
			--]]
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

	return self
end


return Hub
