local errors = require("levee.errors")
local d = require("levee.d")


local UNBUFFERED = 1
local BUFFERED = 2


--
-- Pair

-- Convenience to namespace a sender / recver pair

local Pair_mt = {}
Pair_mt.__index = Pair_mt


function Pair_mt:pass(err, value)
	return self.sender:pass(err, value)
end


function Pair_mt:send(value)
	return self.sender:send(value)
end


function Pair_mt:error(err)
	return self.sender:pass(err)
end


function Pair_mt:recv(ms)
	return self.recver:recv(ms)
end


function Pair_mt:close()
	self.sender:close()
	self.recver:close()
end


local function Pair(sender, recver)
	return setmetatable({sender=sender, recver=recver}, Pair_mt)
end


--
-- Sender

local Sender_mt = {}
Sender_mt.__index = Sender_mt


function Sender_mt:pass(errvalue, value)
	assert(not self.co)

	if self.closed then return errors.CLOSED end

	local err, continued = self.recver:_give(errvalue, self, value)

	if err == errors.CLOSED then
		self.closed = true
		return err
	end

	if continued then
		if continued == UNBUFFERED then self.hub:continue() end
		return
	end

	self.errvalue = errvalue
	self.value = value
	self.co = coroutine.running()
	local err, sender, continued = self.hub:pause()

	if err == errors.CLOSED then
		self.closed = true
		return err
	end

	if continued then return end

	return self:pass(errvalue, value)
end


function Sender_mt:send(value)
	return self:pass(nil, value)
end


function Sender_mt:error(errvalue)
	return self:pass(errvalue)
end


function Sender_mt:_take(err)
	if self.closed then return errors.CLOSED end

	if not self.co then return end

	self.hub:resume(self.co, err, nil, true)
	local errvalue = self.errvalue
	local value = self.value
	self.co = nil
	self.errvalue = nil
	self.value = nil
	return errvalue, value
end


function Sender_mt:_link(recver)
	self.recver = recver
	if not self.co then return end
	self.hub:resume(self.co)
	self.co = nil
	self.value = nil
	self.errvalue = nil
end


function Sender_mt:close()
	if self.closed then return errors.CLOSED end
	self.closed = true

	local err, continued = self.recver:_give(errors.CLOSED, self)
	if continued == UNBUFFERED then self.hub:continue() end
end


local function Sender(hub)
	return setmetatable({hub=hub}, Sender_mt)
end


--
-- Recver

local Recver_mt = {}
Recver_mt.__index = Recver_mt


function Recver_mt:recv(ms)
	assert(not self.co)

	if self.closed then return errors.CLOSED end

	local err, value = self.sender:_take()

	if err or value then return err, value end

	self.co = coroutine.running()
	local err, sender, value = self.hub:pause(ms)
	self.co = nil
	return err, value
end


function Recver_mt:_give(err, sender, value)
	if self.closed then return errors.CLOSED end

	if not self.co then return end

	if err == errors.CLOSED then self.closed = true end

	local co = self.co
	self.co = nil
	self.hub:resume(co, err, sender, value)
	return nil, UNBUFFERED
end


function Recver_mt:__call()
	local err, value = self:recv()
	if err then return end
	return value
end


function Recver_mt:redirect(target)
	if self.closed then return errors.CLOSED end
	assert(not self.co)
	target:_link(self.sender, self)
	self.sender:_link(target)
	self.sender = nil
	self.closed = true
end


function Recver_mt:_link(sender)
	self.sender = sender
end


function Recver_mt:close()
	if self.closed then return errors.CLOSED end
	self.closed = true
	self.sender:_take(errors.CLOSED)
end


local function Recver(hub)
	return setmetatable({hub=hub}, Recver_mt)
end


--
-- Value

local Value_mt = {}
Value_mt.__index = Value_mt


function Value_mt:send(value)
	if self.closed then return errors.CLOSED end
	self.value = value
	local err, continued = self.recver:_give(nil, self, value)
	if continued == UNBUFFERED then self.hub:continue() end
end


function Value_mt:_take(err)
	if self.closed then return errors.CLOSED end
	return nil, self.value
end


function Value_mt:_link(recver)
	self.recver = recver
end


function Value_mt:close()
	if self.closed then return errors.CLOSED end
	self.closed = true
	local err, continued = self.recver:_give(errors.CLOSED, self)
	if continued == UNBUFFERED then self.hub:continue() end
end


local function Value(hub, value)
	return setmetatable({hub=hub, value=value}, Value_mt)
end


--
-- Flag

local Flag_mt = {}
Flag_mt.__index = Flag_mt


function Flag_mt:send(value)
	if self.closed then return errors.CLOSED end
	local err, continued = self.recver:_give(nil, self, value)
	if not continued then self.value = value end
end


function Flag_mt:_take(err)
	if self.closed then return errors.CLOSED end
	if not self.value then return end
	local value = self.value
	self.value = nil
	return nil, value
end


function Flag_mt:close()
	if self.closed then return errors.CLOSED end
	self.closed = true
	self.recver:_give(errors.CLOSED, self)
end


local function Flag(hub, value)
	return setmetatable({hub=hub, value=value}, Flag_mt)
end


--
-- Gate

local Gate_mt = {}
Gate_mt.__index = Gate_mt


function Gate_mt:send(value)
	assert(not self.co)

	if self.closed then return errors.CLOSED end

	local err, continued = self.recver:_give(nil, self, value)

	if err == errors.CLOSED then
		self.closed = true
		return err
	end

	if not continued then self.value = value end

	self.co = coroutine.running()
	local err, sender, continued = self.hub:pause()

	if err == errors.CLOSED then
		self.closed = true
		return err
	end

	if continued then return end

	return self:send(value)
end


function Gate_mt:_take(err)
	if self.closed then return errors.CLOSED end

	-- there's no sender at all, block
	if not self.co then return end

	-- there's a sender with a value waiting. take the value, but leave the
	-- sender blocked.
	if self.value then
		local value = self.value
		self.value = nil
		return nil, value
	end

	-- we've already taken the sender's value. resume the sender.
	self.hub:resume(self.co, err, nil, true)
	self.co = nil
end


function Gate_mt:close()
	if self.closed then return errors.CLOSED end
	self.closed = true
	local err, continued = self.recver:_give(errors.CLOSED, self)
	if continued == UNBUFFERED then self.hub:continue() end
end


local function Gate(hub)
	return setmetatable({hub=hub}, Gate_mt)
end


--
-- Queue

-- A queue is exactly one Sender and one Recver with a fifo in between. Sends
-- won't block until the fifo is filled.

local Queue_mt = {}
Queue_mt.__index = Queue_mt


Queue_mt.__call = Recver_mt.__call


function Queue_mt:_give(err, sender, value)
	if self.closed then return errors.CLOSED end

	if err == errors.CLOSED then self.closed = true end

	if not self.co then
		if self.size and #self.fifo >= self.size then return end
		self.fifo:push({err, sender, value})
		self.empty:send()
		return nil, BUFFERED
	end

	local co = self.co
	self.co = nil
	self.hub:resume(co, err, sender, value)
	return nil, BUFFERED
end


function Queue_mt:recv(ms)
	assert(not self.co)

	if #self.fifo > 0 then
		self.sender:_link(self)
		local err, sender, value = unpack(self.fifo:pop())
		if #self.fifo == 0 then self.empty:send(true) end
		return err, value
	end

	if self.closed then return errors.CLOSED end

	self.co = coroutine.running()
	local err, sender, value = self.hub:pause(ms)
	self.co = nil
	return err, value
end


function Queue_mt:close()
	if self.closed then return errors.CLOSED end
	self.closed = true
	self.sender:_take(errors.CLOSED)
	if self.on_close then
		self.on_close(self)
	end
end


local function Queue(hub, size)
	return setmetatable({
		hub = hub,
		size = size,
		fifo = d.Fifo(),
		empty = Pair(hub:value(true)), }, Queue_mt)
end


--
-- Stalk

-- A Stalk is a delayed queue. recv-ing on the Stalk returns true once there
-- are items in the queue, but it doesn't actually return a sent item. The
-- queue can then be processed and optionally cleared. Once cleared if there is
-- a pending upstream sender it will be signaled to continue.

local Stalk_mt = {}
Stalk_mt.__index = Stalk_mt


function Stalk_mt:_give(err, sender, value)
	if self.closed then return errors.CLOSED end

	if err == errors.CLOSED then self.closed = true end

	if self.size and #self.fifo >= self.size then return end

	self.fifo:push({err, sender, value})
	self.empty:send()

	if self.co then
		local co = self.co
		self.co = nil
		self.hub:resume(co, nil, sender, true)
	end

	return nil, BUFFERED
end


function Stalk_mt:recv(ms)
	assert(not self.co)

	if #self.fifo > 0 then
		return nil, true
	end

	if self.closed then return errors.CLOSED end

	self.co = coroutine.running()
	local err, sender, value = self.hub:pause(ms)
	self.co = nil
	return err, value
end


function Stalk_mt:__len()
	return #self.fifo
end


function Stalk_mt:iter()
	local f = self.fifo:iter()
	return function()
		while true do
			local item = f()
			if not item then return end
			local err, sender, value = unpack(item)
			if err then return end
			return value
		end
	end
end


function Stalk_mt:remove(n)
	assert(n > 0 and n <= #self)
	self.fifo:remove(n)
	self.sender:_link(self)
	if #self == 0 then
		self.empty:send(true)
	end
end


local function Stalk(hub, size)
	return setmetatable({
		hub = hub,
		size = size,
		fifo = d.Fifo(),
		empty = Pair(hub:value(true)), }, Stalk_mt)
end


--
-- Selector

local Selector_mt = {}
Selector_mt.__index = Selector_mt


function Selector_mt:_link(sender, recver)
	self.senders[sender] = recver
end


function Selector_mt:_give(err, sender, value)
	if self.closed then return errors.CLOSED end

	if not self.co then
		self.fifo:push(sender)
		return
	end

	if err == errors.CLOSED and not sender then self.closed = true end

	local co = self.co
	self.co = nil
	self.hub:resume(co, err, sender, value)
	return nil, UNBUFFERED
end


function Selector_mt:recv(ms)
	assert(not self.co)

	local err, sender, value

	if #self.fifo > 0 then
		sender = self.fifo:pop()
		err, value = sender:_take()
	else
		self.co = coroutine.running()
		err, sender, value = self.hub:pause(ms)
		self.co = nil
	end

	local recver = self.senders[sender]
	if err and recver then self.senders[sender] = nil end
	return err, recver, value
end


function Selector_mt:__call()
	local err, sender, value = self:recv()
	if err then return end
	return sender, value
end


local function Selector(hub)
	local self = setmetatable({
		hub=hub,
		fifo=d.Fifo(),
		senders={}, }, Selector_mt)
	return self
end


--
-- Router
-- ... specialized sender

local Router_mt = {}
Router_mt.__index = Router_mt


function Router_mt:pass(errvalue, value)
	if self.closed then return errors.CLOSED end

	local err, continued = self.recver:_give(errvalue, self, value)

	if err == errors.CLOSED then
		self.closed = true
		return err
	end

	if continued then
		if continued == UNBUFFERED then self.hub:continue() end
		return
	end

	self.fifo:push({errvalue, coroutine.running(), value})

	local err, sender, continued = self.hub:pause()

	if err == errors.CLOSED then
		self.closed = true
		return err
	end

	if continued then return end

	return self:pass(errvalue, value)
end


Router_mt.send = Sender_mt.send
Router_mt.error = Sender_mt.error


function Router_mt:_take(err)
	if self.closed then return errors.CLOSED end

	if #self.fifo == 0 then return end

	if err == errors.CLOSED then
		self.closed = true
		if #self.fifo > 0 then
			while #self.fifo > 0 do
				local __, co, __ = unpack(self.fifo:pop())
				self.hub:resume(co, err, nil, false)
			end
			self.hub:continue()
		end
		return
	end

	local errvalue, co, value = unpack(self.fifo:pop())
	self.hub:resume(co, err, nil, true)
	return errvalue, value
end


local function Router(hub)
	return setmetatable({hub = hub, fifo = d.Fifo()}, Router_mt)
end


--
-- Dealer
-- ... specialized recver

local Dealer_mt = {}
Dealer_mt.__index = Dealer_mt


function Dealer_mt:recv(ms)
	if self.closed then return errors.CLOSED end

	local err, value = self.sender:_take()
	if err or value then return err, value end

	self.pri = self.pri + 1
	local wait = self.heap:push(self.pri, coroutine.running())
	local err, sender, value = self.hub:pause(ms)
	if err == errors.TIMEOUT then wait:remove() end
	return err, value
end


function Dealer_mt:_give(err, sender, value)
	if self.closed then return errors.CLOSED end

	if #self.heap == 0 then return end

	if err == errors.CLOSED then
		self.closed = true
		for pri, co in self.heap:popiter() do
			self.hub:resume(co, err, sender, value)
		end
	else
		local pri, co = self.heap:pop()
		self.hub:resume(co, err, sender, value)
	end

	return nil, UNBUFFERED
end


function Dealer_mt:__call()
	local err, value = self:recv()
	if err then return end
	return value
end


function Dealer_mt:close()
	if self.closed then return errors.CLOSED end
	self.closed = true
	self.sender:_take(errors.CLOSED)
	self:_give(errors.CLOSED)
end


local function Dealer(hub)
	return setmetatable({hub=hub, heap=d.Heap(), pri=0}, Dealer_mt)
end


--
-- Broadcast

local Broadcast_mt = {}
Broadcast_mt.__index = Broadcast_mt


function Broadcast_mt:recv(ms)
	if self.closed then return errors.CLOSED end

	local err, value = self.sender:_take()
	if err or value then return err, value end

	local wait = self.heap:push(ms or -1, coroutine.running())
	local err, sender, value = self.hub:pause(ms)
	if err == errors.TIMEOUT then wait:remove() end
	return err, value
end


function Broadcast_mt:_link(sender, recver)
	self.sender = sender
end


function Broadcast_mt:_give(err, sender, value)
	if self.closed then return errors.CLOSED end

	if #self.heap == 0 then return nil, BUFFERED end

	if err == errors.CLOSED then assert(false, "TODO") end

	for pri, co in self.heap:popiter() do
		self.hub:resume(co, err, sender, value)
	end

	return nil, UNBUFFERED
end


function Broadcast_mt:__call()
	local err, value = self:recv()
	if err then return end
	return value
end


local function Broadcast(hub)
	return setmetatable({hub=hub, heap=d.Heap()}, Broadcast_mt)
end


--
-- Pool

-- A finite pool of resources to be shared.

local Pool_mt = {}
Pool_mt.__index = Pool_mt


function Pool_mt:send(item)
	return self.checkin.sender:send(item)
end


function Pool_mt:recv(ms)
	return self.checkout.recver:recv(ms)
end


function Pool_mt:run(f, ...)
	local err, item = self:recv()
	if err then return err end
		-- TODO: should we wrap in a pcall?
	local err, value = f(item, ...)
	self:send(item)
	return err, value
end


local function Pool(hub, factory, size)
	local self = setmetatable({}, Pool_mt)
	self.hub = hub
	self.factory = factory
	self.size = size

	-- TODO:
	-- I'm pretty sure Queue and Stalk to be reworked to be Senders. Then a Queue
	-- sender could be paired directly with a Dealer recver, without all this -->
	self.checkin = {}
	self.checkin.sender = Sender(hub)
	self.checkin.recver = Queue(hub, size)
	self.checkin.sender.recver = self.checkin.recver
	self.checkin.recver.sender = self.checkin.sender

	self.checkout = {}
	self.checkout.sender = Sender(hub)
	self.checkout.recver = Dealer(hub)
	self.checkout.sender.recver = self.checkout.recver
	self.checkout.recver.sender = self.checkout.sender

	self.hub:spawn(function()
		for item in self.checkin.recver do
			local err = self.checkout.sender:send(item)
			if err then break end
		end
		self.checkout.sender:close()
	end)

	for i = 1, size do self:send(factory()) end

	return self
end


----


return {
	Pair = Pair,
	Sender = Sender,
	Recver = Recver,
	Value = Value,
	Flag = Flag,
	Gate = Gate,
	Queue = Queue,
	Stalk = Stalk,
	Selector = Selector,
	Router = Router,
	Dealer = Dealer,
	Broadcast = Broadcast,
	Pool = Pool,
	}
