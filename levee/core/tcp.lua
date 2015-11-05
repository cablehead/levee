local ffi = require("ffi")
local C = ffi.C

local errors = require("levee.errors")
local _ = require("levee._")


local Listener_mt = {}
Listener_mt.__index = Listener_mt


Listener_mt.recv = function(self)
	return self.recver:recv()
end


Listener_mt.__call = function(self)
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


local function _connect(port, host)
	local _ = require("levee._")
	local err, no = _.connect(host, port)
	-- TODO: need to be able to send errors through channels
	if err then return end
	return no
end


function TCP_mt:connect(port, host, timeout)
	local recver = self.hub.thread:call(_connect, port, host or "127.0.0.1")
	local err, no = recver:recv()
	if err then return err end
	-- TODO: ^^
	if not no then
		return errors.system.EADDRNOTAVAIL
	end
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
