local ffi = require('ffi')
local C = ffi.C


local errors = require("levee.errors")
local _ = require("levee._")
local d = require("levee.d")


local message = require("levee.core.message")


local log = _.log.Log("levee.core.hub")


local State_mt = {}
State_mt.__index = State_mt


function State_mt:recv(timeout)
	if self.value then
		local value = self.value
		self.value = nil
		return nil, nil, value
	end

	self.co = coroutine.running()
	local err, sender, value = self.hub:pause(timeout)
	self.co = nil
	return err, sender, value
end


function State_mt:set(value)
	if not self.co then
		self.value = value
		return
	end

	local co = self.co
	self.co = nil
	self.hub:_coresume(co, nil, nil, value)
end


local function State(hub)
	local self = setmetatable({hub=hub}, State_mt)
	return self
end


local Trace_mt = {}
Trace_mt.__index = Trace_mt


function Trace_mt:pprint(state)
		local function d(stack, i)
			print(("%s%-50s %3s %3s %3s %10.2f"):format(
				("|       "):rep(i),
				stack.f,
				stack.spawned,
				stack.term,
				stack.n,
				stack.took / (1000 * 1000)))
		end

		local function p(stack, i)
			i = i or 0
			d(stack, i)

			local totals = {f = "-"}
			for k, v in pairs(stack) do
				if k ~= "f" and k ~= "tree" then totals[k] = v end
			end

			if next(stack.tree) then
				for name, substack in pairs(stack.tree) do
					local subtotals = p(substack, i + 1)
					for k, v in pairs(subtotals) do
						if k ~= "f" and k ~= "tree" then totals[k] = totals[k] + v end
					end
				end
				d(totals, i)
			end
			return totals
		end

		state = state or self.state
		p(state.stacks[state.main])
end


function Trace_mt:capture(f, co)
	local info = debug.getinfo(f)
	local source = ("%s:%s"):format(info.short_src, info.linedefined)

	local parent = self.threads[coroutine.running()]
	local stack = parent.tree[source] or {
		f = source,
		spawned = 0,
		term = 0,
		n = 0,
		took = 0,
		tree = {}, }

	parent.tree[source] = stack
	self.threads[co] = stack

	stack.spawned = stack.spawned + 1
	self.state.spawned = self.state.spawned + 1
end


function Trace_mt:context(f)
	if not self.threads or not self.threads[coroutine.running()] then
		return f()
	end

	local info = debug.getinfo(2)
	local source = ("%s:%s"):format(info.short_src, info.currentline)
	local parent = self.threads[coroutine.running()]
	local stack = parent.tree[source] or {
		f = source,
		spawned = 0,
		term = 0,
		n = 0,
		took = 0,
		tree = {}, }
	parent.tree[source] = stack
	self.threads[coroutine.running()] = stack

	local ret = {f()}

	self.threads[coroutine.running()] = parent

	return unpack(ret)
end


function Trace_mt:patch()
	self.save = {
		_coresume = self.r.hub._coresume,
		spawn = self.r.hub.spawn,
		spawn_later = self.r.hub.spawn_later, }

	self.r.hub._coresume = function(hub, co, err, sender, value)
		local took = _.time.Timer()
		self.save._coresume(hub, co, err, sender, value)
		took:finish()

		if self.state and self.threads[co] then
			local stack = self.threads[co]
			stack.n = stack.n + 1
			stack.took = stack.took + tonumber(took:nanoseconds())
			-- clean up when a thread completes
			if coroutine.status(co) == "dead" then
				stack.term = stack.term + 1
				self.state.term = self.state.term + 1
				self.threads[co] = nil
			end
		end
	end

	self.r.hub.spawn = function(hub, f, a)
		local co = coroutine.create(f)
		self:capture(f, co)
		hub.ready:push({co, a})
		hub:continue()
	end

	self.r.hub.spawn_later = function (hub, ms, f)
		local co = coroutine.create(f)
		self:capture(f, co)
		ms = hub.poller:abstime(ms)
		hub.scheduled:push(ms, co)
	end
end


function Trace_mt:restore()
	for k, v in pairs(self.save) do self.r.hub[k] = v end
	self.save = nil
end


function Trace_mt:start()
	assert(not self.state)

	self.threads = {}

	self.state = {}
	self.state.spawned = 0
	self.state.term = 0
	self.state.stacks = {}
	self.state.main = self.main

	self.state.stacks[self.main] = {
		f = self.main,
		spawned = 1,
		term = 0,
		n = 0,
		took = 0,
		tree = {}, }

	self.threads[coroutine.running()] = self.state.stacks[self.main]

	self:patch()
end


function Trace_mt:stop()
	self:restore()
	self.threads = nil
	self.state = nil
end


local function Trace(hub)
	local self = setmetatable({}, Trace_mt)

	self.r = setmetatable({}, {__mode="v"})
	self.r.hub = hub

	local info = debug.getinfo(3)
	self.main = ("%s:%s"):format(info.short_src, info.currentline)
	return self
end


local Hub_mt = {}
Hub_mt.__index = Hub_mt


function Hub_mt:pipe()
	local sender = message.Sender(self)
	local recver = message.Recver(self)
	sender.recver = recver
	recver.sender = sender
	return sender, recver
end


function Hub_mt:value(value)
	local sender = message.Value(self, value)
	local recver = message.Recver(self)
	sender.recver = recver
	recver.sender = sender
	return sender, recver
end


function Hub_mt:flag(value)
	local sender = message.Flag(self, value)
	local recver = message.Recver(self)
	sender.recver = recver
	recver.sender = sender
	return sender, recver
end


function Hub_mt:gate()
	local sender = message.Gate(self)
	local recver = message.Recver(self)
	sender.recver = recver
	recver.sender = sender
	return sender, recver
end


function Hub_mt:queue(size)
	local sender = message.Sender(self)
	local recver = message.Queue(self, size)
	sender.recver = recver
	recver.sender = sender
	return sender, recver
end


function Hub_mt:stalk(size)
	local sender = message.Sender(self)
	local recver = message.Stalk(self, size)
	sender.recver = recver
	recver.sender = sender
	return sender, recver
end


function Hub_mt:selector()
	return message.Selector(self)
end


function Hub_mt:router()
	local sender = message.Router(self)
	local recver = message.Recver(self)
	sender.recver = recver
	recver.sender = sender
	return sender, recver
end


function Hub_mt:dealer()
	local sender = message.Sender(self)
	local recver = message.Dealer(self)
	sender.recver = recver
	recver.sender = sender
	return sender, recver
end


function Hub_mt:broadcast()
	return message.Broadcast(self)
end


function Hub_mt:pool(factory, size)
	return message.Pool(self, factory, size)
end


function Hub_mt:_coresume(co, err, sender, value)
	if co ~= self._pcoro then
		local status, target = coroutine.resume(co, err, sender, value)
		if not status then
			log:fatal(debug.traceback(co) .. "\n\n" .. target)
		end
	else
		coroutine.yield(err, sender, value)
	end
end


function Hub_mt:_coyield(co, err, sender, value)
	if coroutine.running() ~= self._pcoro then
		return coroutine.yield(co, err, sender, value)
	end
	local status, err, sender, value = coroutine.resume(
		self.loop, co, err, sender, value)
	if not status then
		log:fatal(("%s\n\n%s"):format(debug.traceback(self.loop), err))
	end
	return err, sender, value
end


function Hub_mt:spawn(f, a)
	local co = coroutine.create(f)
	self.ready:push({co, a})
	self:continue()
end


function Hub_mt:spawn_later(ms, f)
	local co = coroutine.create(f)
	ms = self.poller:abstime(ms)
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
	local err, sender, value = self:_coyield()
	if err ~= errors.TIMEOUT then
		timeout:remove()
	end
	return err, sender, value
end


function Hub_mt:resume(co, err, sender, value)
	self.ready:push({co, err, sender, value})
end


function Hub_mt:continue()
	self.ready:push({coroutine.running()})
	self:_coyield()
end


function Hub_mt:register(no, r, w)
	local r_ev = r and State(self)
	local w_ev = w and State(self)
	self.registered[no] = {r_ev, w_ev}
	self.poller:register(no, r, w)
	return r_ev, w_ev
end


local function EVStub()
	return {
		recv = function() return 1 end,
		set = function() end,
	}
end


function Hub_mt:register_nopoll(no, r, w)
	local r_ev = r and EVStub()
	local w_ev = w and EVStub()
	self.registered[no] = {r_ev, w_ev}
	return r_ev, w_ev
end


function Hub_mt:unregister(no)
	local r = self.registered[no]
	if r then
		table.insert(self.closing, no)

		-- this is only needed if a platform doesn't remove an fd from a poller on
		-- fd close
		-- TODO: detect r, w
		-- self.poller:unregister(no, r, w)

		if r[1] then r[1]:set(-1) end
		if r[2] then r[2]:set(-1) end
		self.registered[no] = nil
	end
end


function Hub_mt:in_use()
	for no in pairs(self.registered) do
		if not self.dialer.state or
				(no ~= self.dialer.r and no ~= self.dialer.state.io[1]) then
			return true
		end
	end
	return false
end


function Hub_mt:pump()
	local num = #self.ready
	for _ = 1, num do
		local co, err, sender, value = unpack(self.ready:pop())
		self:_coresume(co, err, sender, value)
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
			self.thread.chan:pump()

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


local function Hub(options)
	options = options or {}

	local self = setmetatable({}, Hub_mt)

	self.ready = d.Fifo()
	self.scheduled = d.Heap()

	self.registered = {}
	self.poller = _.poller()
	self.closing = {}

	self._pcoro = coroutine.running()
	self.loop = coroutine.create(function()
		local status, err = xpcall(
			function() return self:main() end,
			function(err) return debug.traceback() .. "\n\n" .. err end)
		if not status then
			log:fatal(err .. "\n\nmain loop crashed")
		end
	end)

	self.io = require("levee.core.io")(self)
	self.signal = require("levee.core.signal")(self)
	self.process = require("levee.core.process")(self)
	self.thread = require("levee.core.thread")(self)

	self.stream = require("levee.net.stream")(self)
	self.dgram = require("levee.net.dgram")(self)
	self.dialer = require("levee.net.dialer")(self)
	self.tcp = self.stream

	self.http = require("levee.p.http")(self)
	self.consul = require("levee.app.consul")(self)

	self.trace = Trace(self)
	if options.trace then self.trace:start() end
	return self
end


return Hub
