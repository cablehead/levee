local ffi = require('ffi')
local C = ffi.C


local errors = require("levee.errors")
local _ = require("levee._")
local d = require("levee.d")


-- local Heap = require("levee.heap")
-- local FIFO = require("levee.fifo")
-- local message = require("levee.message")
-- local constants = require("levee.constants")
-- local Channel = require("levee.channel")


local State_mt = {}
State_mt.__index = State_mt


function State_mt:recv(timeout)
	if self.value then
		local value = self.value
		self.value = nil
		return nil, value
	end

	self.co = coroutine.running()
	local err, value = self.hub:pause(timeout)
	self.co = nil
	return err, value
end


function State_mt:set(value)
	if not self.co then
		self.value = value
		return
	end

	local co = self.co
	self.co = nil
	self.hub:_coresume(co, nil, value)
end


function State_mt:__call(value)
	return self:recv()
end


local function State(hub)
	local self = setmetatable({hub=hub}, State_mt)
	return self
end


local Signal_mt = {}
Signal_mt.__index = Signal_mt


function Signal_mt:__call(hub, ...)
	local recver = self.hub:queue()
	self.reverse[recver] = {}

	local sigs = {...}
	for i = 1, #sigs do
		local no = sigs[i]

		if not self.registered[no] then
			self.hub.poller:signal_register(no)
			self.registered[no] = {}
		end

		self.registered[no][recver] = 1
		table.insert(self.reverse[recver], no)
	end

	recver.on_close = function(recver) self:unregister(recver) end
	return recver
end


function Signal_mt:unregister(recver)
	local sigs = self.reverse[recver]
	for i = 1, #sigs do
		local no = sigs[i]
		self.registered[no][recver] = nil

		if not next(self.registered[no]) then
			self.hub.poller:signal_unregister(no)
			self.registered[no] = nil
		end
	end
	self.reverse[recver]= nil
end


function Signal_mt:trigger(no)
	self.hub.poller:signal_clear(no)
	for recver, _ in pairs(self.registered[no]) do
		recver:send(no)
	end
end


local function Signal(hub)
	return setmetatable({hub = hub, registered = {}, reverse = {}}, Signal_mt)
end


local Hub_mt = {}
Hub_mt.__index = Hub_mt


function Hub_mt:pipe()
	return message.Pipe(self)
end


function Hub_mt:gate()
	return message.Gate(self)
end


function Hub_mt:value(value)
	return message.Value(self, value)
end


function Hub_mt:selector()
	return message.Selector(self)
end


function Hub_mt:queue(size)
	return message.Queue(self, size)
end


function Hub_mt:stalk(size)
	return message.Stalk(self, size)
end


function Hub_mt:mimo(size)
	return message.MiMo(self, size)
end


function Hub_mt:_coresume(co, err, value)
	if co ~= self._pcoro then
		local status
		status, co, err, value = coroutine.resume(co, err, value)
		if not status then error(co) end
	else
		co, err, value = coroutine.yield(err, value)
	end
	if co then
		self:_coresume(co, err, value)
	end
end


function Hub_mt:_coyield(co, err, value)
	if coroutine.running() ~= self._pcoro then
		return coroutine.yield(co, err, value)
	end
	local status, err, value = coroutine.resume(self.loop, co, err, value)
	if not status then error(err) end
	return err, value
end


function Hub_mt:spawn(f, a)
	local co = coroutine.create(f)
	self.ready:push({co, a})
	self:continue()
end


function Hub_mt:spawn_later(ms, f)
	ms = self.poller:abstime(ms)
	local co = coroutine.create(f)
	self.scheduled:push(ms, co)
end


function Hub_mt:sleep(ms)
	ms = self.poller:abstime(ms)
	self.scheduled:push(ms, coroutine.running())
	self:_coyield()
end


function Hub_mt:pause(ms)
	if not ms then return self:_coyield() end

	ms = self.poller:abstime(ms)
	local timeout = self.scheduled:push(ms, coroutine.running())
	local err, value = self:_coyield()
	if err ~= errors.TIMEOUT then
		timeout:remove()
	end
	return err, value
end


function Hub_mt:resume(co, err, value)
	self.ready:push({co, err, value})
end


function Hub_mt:continue()
	self.ready:push({coroutine.running()})
	self:_coyield()
end


function Hub_mt:switch_to(co, err, value)
	self.ready:push({coroutine.running()})
	self:_coyield(co, err, value)
end


function Hub_mt:register(no, r, w)
	local r_ev = r and State(self)
	local w_ev = w and State(self)
	self.registered[no] = {r_ev, w_ev}
	self.poller:register(no, r, w)
	return r_ev, w_ev
end


function Hub_mt:unregister(no, r, w)
	local r = self.registered[no]
	if r then
		table.insert(self.closing, no)

		-- this is only needed if a platform doesn't remove an fd from a poller on
		-- fd close
		self.poller:unregister(no, r, w)

		if r[1] then r[1]:set(-1) end
		if r[2] then r[2]:set(-1) end
		self.registered[no] = nil
	end
end


-- TODO: should this just be a normal State object?
function Hub_mt:channel()
	if self.chan == nil then
		self.chan = Channel(self)
	end
	return self.chan
end


function Hub_mt:pump()
	local num = #self.ready
	for _ = 1, num do
		local co, err, value = unpack(self.ready:pop())
		self:_coresume(co, err, value)
	end

	local timeout
	if #self.ready > 0 then
		timeout = 0
	else
		timeout = self.scheduled:peek()
	end

	if #self.closing > 0 then
		for i = 1, #self.closing do
			C.close(self.closing[i])
		end
		self.closing = {}
	end

	local err, events, n = self.poller:poll(timeout)
	assert(not err)

	while true do
		local timeout = self.scheduled:peek()
		if not timeout or self.poller:reltime(timeout) > 0 then
			break
		end
		local ms, co = self.scheduled:pop()
		self:_coresume(co, errors.TIMEOUT)
	end

	for i = 0, n - 1 do
		local no, c_ev, s_ev, r_ev, w_ev, e_ev = events[i]:value()

		if c_ev then
			self.chan:pump()

		elseif s_ev then
			self.signal:trigger(no)

		else
			local r = self.registered[no]
			if r then
				if not e_ev then
					if r_ev then r[1]:set(1) end
					if w_ev then r[2]:set(1) end
				else
					if r[1] then r[1]:set(-1) end
					if r[2] then r[2]:set(-1) end
				end
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

	self.ready = d.fifo()
	self.scheduled = d.heap()

	self.signal = Signal(self)

	self.registered = {}
	self.poller = _.poller()
	self.closing = {}

	self._pcoro = coroutine.running()
	self.loop = coroutine.create(function() self:main() end)

	-- self.io = require("levee.io")(self)
	-- self.tcp = require("levee.tcp")(self)
	-- self.udp = require("levee.udp")(self)
	-- self.http = require("levee.http")(self)
	-- self.thread = require("levee.thread")(self)
	-- self.process = require("levee.process")(self)

	-- self.consul = require("levee.consul")(self)

	return self
end


return Hub
