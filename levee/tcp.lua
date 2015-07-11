local ffi = require("ffi")
local C = ffi.C

local errno = require("levee.errno")
local sys = require("levee.sys")


local function __recv(self)
	return self.recver:recv()
end


local Listener_mt = {}
Listener_mt.__index = Listener_mt

Listener_mt.__call = __recv
Listener_mt.recv = __recv


function Listener_mt:loop()
	for ev in self.r_ev do
		if ev < -1 then
			self:close()
			return
		end

		while true do
			local no, err = sys.socket.accept(self.no)
			-- TODO: only break on EAGAIN, should close on other errors
			if no == nil then break end
			self.recver:send(self.hub.io:rw(no))
		end
	end
end


function Listener_mt:addr()
	return sys.endpoint:sockname(self.no)
end


function Listener_mt:close()
	if self.closed then
		return
	end

	self.closed = true
	self.hub:unregister(self.no, true)
	self.recver:close()
	self.hub:continue()
	return true
end


--
-- TCP module interface
--
local TCP_mt = {}
TCP_mt.__index = TCP_mt


local function _connect(port, host)
	local ffi = require("ffi")
	local C = ffi.C
	local sys = require("levee.sys")
	local getaddrinfo = sys.socket.getaddrinfo
	local connect = sys.socket.connect
	return connect(port, host)
end


function TCP_mt:connect(port, host)
	local recver = self.hub.thread:call(_connect, port, host or "127.0.0.1")
	local no, err = recver:recv()
	if not no then
		return no, err
	end
	sys.os.nonblock(no)
	return self.hub.io:rw(no)
end


function TCP_mt:listen(port, host)
	local no, err = sys.socket.listen(C.AF_INET, C.SOCK_STREAM, port, host)
	if err then
		error(errno:message(err))
	end
	sys.os.nonblock(no)
	local m = setmetatable({hub = self.hub, no = no}, Listener_mt)
	m.r_ev = self.hub:register(no, true)
	m.recver = self.hub:pipe()
	self.hub:spawn(m.loop, m)
	return m
end


return function(hub)
	return setmetatable({hub = hub}, TCP_mt)
end
