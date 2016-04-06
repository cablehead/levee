local ffi = require("ffi")
local C = ffi.C

local errors = require("levee.errors")
local _ = require("levee._")
local Dialer = require("levee.core.dialer")


local Listener_mt = {}
Listener_mt.__index = Listener_mt


function Listener_mt:recv()
	return self.recver:recv()
end


function Listener_mt:__call()
	local err, value = self.recver:recv()
	if not err then return value end
end


function Listener_mt:loop()
	while true do
		local err, sender, ev = self.r_ev:recv()
		if ev < -1 then
			self:close()
			return
		end

		while true do
			local err, no = _.accept(self.no)
			-- TODO: only break on EAGAIN, should close on other errors
			if err then break end
			_.fcntl_nonblock(no)
			self.sender:send(self.hub.io:rw(no, self.timeout))
		end
	end
end


function Listener_mt:addr()
	return _.getsockname(self.no)
end


function Listener_mt:close()
	if self.closed then
		return
	end

	self.closed = true
	self.hub:unregister(self.no, true)
	self.sender:close()
	self.hub:continue()
	return true
end


--
-- TCP module interface
--

local TCP_mt = {}
TCP_mt.__index = TCP_mt


function TCP_mt:connect(port, host, timeout)
	if not self.dialer then
		self.dialer = self.hub:pool(function()
			return Dialer(self.hub, C.SOCK_STREAM)
		end, 1)
	end
	local err, no = self.dialer:run(function(dialer)
		return dialer:dial(host, port)
	end)
	if err then return err end
	_.fcntl_nonblock(no)
	return nil, self.hub.io:rw(no, timeout)
end


function TCP_mt:listen(port, host, timeout)
	local err, no = _.listen(C.AF_INET, C.SOCK_STREAM, host, port)
	if err then return err end
	_.fcntl_nonblock(no)
	local m = setmetatable({hub = self.hub, no = no}, Listener_mt)
	m.r_ev = self.hub:register(no, true)
	m.sender, m.recver = self.hub:pipe()
	m.timeout = timeout
	self.hub:spawn(m.loop, m)
	return nil, m
end


return function(hub)
	return setmetatable({hub = hub}, TCP_mt)
end
