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
			self.hub:unregister(self.no, true)
			self.recver:close()
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


--
-- TCP module interface
--
local TCP_mt = {}
TCP_mt.__index = TCP_mt


function TCP_mt:connect(port, host)
	local no = sys.socket.connect(port, host or "127.0.0.1")
	sys.os.nonblock(no)
	return self.hub.io:rw(no)
end


function TCP_mt:listen(port, host)
	local no = sys.socket.listen(port, host)
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
