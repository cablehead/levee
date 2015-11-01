local errors = require("levee.errors")
local d = require("levee.d")


--
-- Sender


local Sender_mt = {}
Sender_mt.__index = Sender_mt


function Sender_mt:send(value)
	assert(not self.co)

	if self.closed then return errors.CLOSED end

	local err, ok = self.recver:_give(nil, value)

	if err == errors.CLOSED then
		self.closed = true
		return err
	end

	if ok then return end

	self.value = value
	self.co = coroutine.running()
	return self.hub:_coyield()
end


function Sender_mt:_take(err)
	if self.closed then return errors.CLOSED end

	if not self.co then return end

	self.hub:resume(self.co, err)
	local value = self.value
	self.co = nil
	self.value = nil
	return nil, value
end


function Sender_mt:close()
	if self.closed then return errors.CLOSED end
	self.closed = true
	self.recver:_give(errors.CLOSED)
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
	local err, value = self.hub:pause(ms)
	self.co = nil
	return err, value
end


function Recver_mt:_give(err, value)
	if self.closed then return errors.CLOSED end

	if not self.co then return end

	if err == errors.CLOSED then self.closed = true end

	local co = self.co
	self.co = nil
	self.hub:switch_to(co, err, value)
	return nil, true
end


function Recver_mt:__call()
	local err, value = self:recv()
	if err then return end
	return value
end


function Recver_mt:close()
	if self.closed then return errors.CLOSED end
	self.closed = true
	self.sender:_take(errors.CLOSED)
end


local function Recver(hub)
	return setmetatable({hub=hub}, Recver_mt)
end


local function redirect(target)
	print("redirect", target)
	if true then return end

	assert(not self.recver)

	self.target = target
	self = setmetatable(self, Redirect_mt)

	if self.sender then
		assert(not self.target:give(self, value))
	end

	return self
end





--
-- Value

local Value_mt = {}
Value_mt.__index = Value_mt


function Value_mt:send(value)
	self.value = value

	if self.recver then
		local co = self.recver
		self.recver = nil
		self.hub:switch_to(co, value)
	end

	return true
end


function Value_mt:recv(timeout)
	if self.value ~= nil then return self.value end

	self.recver = coroutine.running()
	local ret = self.hub:pause(timeout)
	-- TODO: handle comprehensively
	self.recver = nil
	return ret
end


local function Value(hub, value)
	local self = setmetatable({hub=hub, value=value}, Value_mt)
	return self
end


--
-- Redirect

local Redirect_mt = {}
Redirect_mt.__index = Redirect_mt


function Redirect_mt:send(value)
	assert(not self.sender)

	if self.closed then
		return
	end

	if self.target:give(self, value) then
		return true
	end

	self.value = value
	self.sender = coroutine.running()
	return self.hub:_coyield()
end


function Redirect_mt:take()
	if self.closed then
		return
	end

	assert(self.sender)

	local value = self.value
	self.value = nil
	local co = self.sender
	self.sender = nil
	self.hub.ready:push({co, true})
	return value
end


function Redirect_mt:redirect(target)
	assert(not self.recver)
	self.target = target
end


function Redirect_mt:close()
	if self.closed then
		return
	end

	self.closed = true
	self.target:give(self, nil)
end


--
-- Gate

local Gate_mt = {}
Gate_mt.__index = Gate_mt


function Gate_mt:send(value)
	assert(not self.sender)

	if self.closed then
		return
	end

	if self.recver then
		local co = self.recver
		self.recver = nil
		self.hub.ready:push({co, value})
	else
		self.value = value
	end

	self.sender = coroutine.running()
	return self.hub:_coyield()
end


function Gate_mt:recv(timeout)
	assert(not self.recver)

	if self.closed then
		return
	end

	if self.value then
		local value = self.value
		self.value = nil
		return value
	end

	if self.sender then
		local co = self.sender
		self.sender = nil
		self.hub.ready:push({co, true})
	end

	self.recver = coroutine.running()
	local ret = self.hub:pause(timeout)
	-- TODO: handle comprehensively
	self.recver = nil
	return ret
end


function Gate_mt:__call(timeout)
	return self:recv(timeout)
end


function Gate_mt:redirect(target)
	assert(not self.recver)

	self.target = target
	self = setmetatable(self, Redirect_mt)

	if self.sender then
		assert(not self.target:give(self, value))
	end

	return self
end


function Gate_mt:close()
	if self.closed then
		return
	end

	self.closed = true

	if self.recver then
		local co = self.recver
		self.recver = nil
		self.hub.ready:push({co})
	elseif self.sender then
		local co = self.sender
		self.sender = nil
		self.hub.ready:push({co})
	end

	self.hub:continue()
	return true
end


local function Gate(hub)
	local self = setmetatable({hub=hub}, Gate_mt)
	return self
end


--
-- Queue

-- A queue is exactly one Sender and one Recver with a fifo in between. Sends
-- won't block until the fifo is filled.

local Queue_mt = {}
Queue_mt.__index = Queue_mt


function Queue_mt:send(value)
	assert(not self.sender)

	if self.closed then
		return
	end

	if self.recver then
		local co = self.recver
		self.recver = nil
		self.hub.ready:push({co, value})
		return true
	end

	self.empty:send()

	if not self.size or #self.fifo < self.size then
		self.fifo:push(value)
		return true
	end

	self.fifo:push(value)
	self.sender = coroutine.running()
  return self.hub:_coyield()
end


function Queue_mt:recv()
	assert(not self.recver)

	if self.sender then
		local co = self.sender
		self.sender = nil
		self.hub.ready:push({co, true})
	end

	if #self.fifo > 0 then
		if #self.fifo == 1 then
			self.empty:send(true)
		end
		return self.fifo:pop()
	end

	if self.closed then
		return
	end

	self.recver = coroutine.running()
	return self.hub:_coyield()
end


function Queue_mt:__call()
	return self:recv()
end


function Queue_mt:close()
	if self.closed then
		return
	end

	self.closed = true

	-- TODO: these 1st two conditions need tests
	if self.recver then
		local co = self.recver
		self.recver = nil
		self.hub.ready:push({co})
	elseif self.sender then
		local co = self.sender
		self.sender = nil
		self.hub.ready:push({co})

	elseif #self.fifo > 0 then
		self.fifo:push(nil)
	end

	if self.on_close then
		self.on_close(self)
	end
end


local function Queue(hub, size)
	local self = setmetatable({
		hub=hub,
		size=size,
		fifo=FIFO(),
		empty=hub:value(true), }, Queue_mt)
	return self
end


--
-- Stalk

-- A Stalk is a delayed queue. recv-ing on the Stalk returns true once there
-- are items in the queue, but it doesn't actually return a sent item. The
-- queue can then be processed and optionally cleared. Once cleared if there is
-- a pending upstream sender it will be signaled to continue.

local Stalk_mt = {}
Stalk_mt.__index = Stalk_mt


function Stalk_mt:send(value)
	assert(not self.sender)

	if self.closed then
		return
	end

	if self.size and #self.fifo >= self.size then
		self.sender = coroutine.running()
		local rc = self.hub:_coyield()
		if not rc then return end
	end

	self.fifo:push(value)
	self.empty:send()

	if self.recver then
		local co = self.recver
		self.recver = nil
		self.hub.ready:push({co, true})
	end

	return true
end


function Stalk_mt:recv()
	assert(not self.recver)

	if #self.fifo > 0 then
		return true
	end

	if self.closed then
		return
	end

	self.recver = coroutine.running()
	return self.hub:_coyield()
end


function Stalk_mt:__call()
	return self:recv()
end


function Stalk_mt:__len()
	return #self.fifo
end


function Stalk_mt:iter()
	return self.fifo:iter()
end


function Stalk_mt:remove(n)
	assert(n > 0 and n <= #self)

	self.fifo:remove(n)

	if #self == 0 then
		self.empty:send(true)
	end

	if self.sender then
		local co = self.sender
		self.sender = nil
		self.hub.ready:push({co, true})
	end
end


function Stalk_mt:close()
	if self.closed then
		return
	end

	self.closed = true

	-- TODO: these 1st two conditions need tests
	if self.recver then
		local co = self.recver
		self.recver = nil
		self.hub.ready:push({co})
	elseif self.sender then
		local co = self.sender
		self.sender = nil
		self.hub.ready:push({co})
	end

	if self.on_close then
		self.on_close(self)
	end
end


local function Stalk(hub, size)
	local self = setmetatable({
		hub=hub,
		size=size,
		fifo=FIFO(),
		empty=hub:value(true), }, Stalk_mt)
	return self
end


--
-- Selector

local Selector_mt = {}
Selector_mt.__index = Selector_mt


function Selector_mt:give(sender, value)
	if self.recver then
		local co = self.recver
		self.recver = nil
		-- TODO: there's a race condition here with timeout
		-- need to check Pipe and Queue to see if they have the same issue
		self.hub:switch_to(co, {sender, value})
		-- self.hub.ready:push({co, {sender, value}})
		return true
	end

	self.fifo:push(sender)
	return false
end


function Selector_mt:recv(timeout)
	assert(not self.recver)

	if #self.fifo > 0 then
		local sender = self.fifo:pop()
		return {sender, sender:take()}
	end

	self.recver = coroutine.running()
	local ret = self.hub:pause(timeout)
	-- TODO: handle comprehensively
	self.recver = nil
	return ret
end


function Selector_mt:__call(timeout)
	return self:recv(timeout)
end


local function Selector(hub)
	local self = setmetatable({hub=hub, fifo=FIFO(), }, Selector_mt)
	return self
end


--
-- Pair

-- Convenience to namespace a sender / recver pair

local Pair_mt = {}
Pair_mt.__index = Pair_mt


function Pair_mt:send(value)
	return self.sender:send(value)
end


function Pair_mt:recv()
	return self.recver:recv()
end


local function Pair(sender, recver)
	return setmetatable({sender=sender, recver=recver}, Pair_mt)
end


----

return {
	Sender = Sender,
	Recver = Recver,

	Value = Value,
	Gate = Gate,
	Queue = Queue,
	Stalk = Stalk,
	Selector = Selector,
	Pair = Pair,
	}
