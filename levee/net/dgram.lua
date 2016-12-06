local _ = require("levee._")


local Dgram_mt = {}
Dgram_mt.__index = Dgram_mt


function Dgram_mt:sendto(endpoint, buf, len)
	if self.closed then return errors.CLOSED end
	return _.sendto(self.no, endpoint, buf, len)
end


function Dgram_mt:recvfrom(buf, len)
	if self.closed then return errors.CLOSED end

	local err, who, n = _.recvfrom(self.no, buf, len)
	if not err then return nil, who, n end
	if not err.is_system_EAGAIN then return err end

	local err, sender, ev = self.r_ev:recv(self.timeout)
	if err then return err end
	if ev < 0 then
		self:close()
		return errors.CLOSED
	end

	return self:recvfrom(buf, len)
end


function Dgram_mt:addr()
	return _.getsockname(self.no)
end


function Dgram_mt:close()
	if self.closed then
		return errors.CLOSED
	end

	self.closed = true
	self.hub:unregister(self.no, true)
	self.hub:continue()
	return
end


local function Dgram(hub, no)
	local self = setmetatable({}, Dgram_mt)
	self.hub = hub
	self.no = no
	self.r_ev = self.hub:register(no, true)
	return self
end


local UDP_mt = {}
UDP_mt.__index = UDP_mt


function UDP_mt:bind(port, host)
	local err, no = _.bind(C.AF_INET, C.SOCK_DGRAM, host, port)
	if err then return err end
	_.fcntl_nonblock(no)
	return nil, Dgram(self.hub, no)
end


function UDP_mt:dial(port, host)
	local err, no = self.hub.dialer:dial(C.AF_INET, C.SOCK_DGRAM, host, port)
	if err then return err end
	_.fcntl_nonblock(no)
	return nil, self.hub.io:w(no)
end


function UDP_mt:listen(port, host)
	local err, no = _.listen(C.AF_INET, C.SOCK_DGRAM, host, port)
	if err then return err end
	_.fcntl_nonblock(no)
	return nil, self.hub.io:r(no)
end


return function(hub)
	return setmetatable({hub = hub}, UDP_mt)
end
