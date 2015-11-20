local errors = require("levee.errors")
local d = require("levee.d")


local UNBUFFERED = 1
local BUFFERED = 2


--
-- Pair

-- Convenience to namespace a sender / recver pair

local Pair_mt = {}
Pair_mt.__index = Pair_mt


function Pair_mt:send(value)
	return self.sender:send(value)
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


function Sender_mt:send(value)
	assert(not self.co)

	if self.closed then return errors.CLOSED end

	local err, continued = self.recver:_give(nil, self, value)

	if err == errors.CLOSED then
		self.closed = true
		return err
	end

	if continued then
		if continued == UNBUFFERED then self.hub:continue() end
		return
	end

	self.value = value
	self.co = coroutine.running()
	local err, sender, continued = self.hub:pause()

	if err == errors.CLOSED then
		self.closed = true
		return err
	end

	if continued then return end

	return self:send(value)
end


function Sender_mt:_take(err)
	if self.closed then return errors.CLOSED end

	if not self.co then return end

	self.hub:resume(self.co, err, nil, true)
	local value = self.value
	self.co = nil
	self.value = nil
	return nil, value
end


function Sender_mt:_link(recver)
	self.recver = recver
	if not self.co then return end
	self.hub:resume(self.co)
	self.co = nil
	self.value = nil
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
			item = f()
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

	if err == errors.CLOSED then self.closed = true end

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
-- Dealer

local Dealer_mt = {}
Dealer_mt.__index = Dealer_mt


function Dealer_mt:recv(ms)
	if self.closed then return errors.CLOSED end

	local err, value = self.sender:_take()
	if err or value then return err, value end

	self.fifo:push(coroutine.running())
	local err, sender, value = self.hub:pause(ms)
	return err, value
end


function Dealer_mt:_give(err, sender, value)
	if self.closed then return errors.CLOSED end

	if #self.fifo == 0 then return end

	if err == errors.CLOSED then
		self.closed = true
		for co in self.fifo:iter() do
			self.hub:resume(co, err, sender, value)
		end
	else
		local co = self.fifo:pop()
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
	return setmetatable({hub=hub, fifo=d.Fifo()}, Dealer_mt)
end


----


return {
	Sender = Sender,
	Recver = Recver,
	Value = Value,
	Flag = Flag,
	Gate = Gate,
	Queue = Queue,
	Stalk = Stalk,
	Selector = Selector,
	Dealer = Dealer,
	Pair = Pair,
	}
