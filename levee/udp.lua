local ffi = require("ffi")
local C = ffi.C

local errno = require("levee.errno")
local sys = require("levee.sys")


local Socket_mt = {}
Socket_mt.__index = Socket_mt


function Socket_mt:sendto(addr, buf, len)
	local n = C.sendto(
		self.no, buf, len, 0, ffi.cast("struct sockaddr *", addr), ffi.sizeof(addr))
	assert(n == len)
end


function Socket_mt:recvfrom(addr, buf, len)
	local addr_len = ffi.new("socklen_t[1]")
	addr_len[0] = ffi.sizeof(addr)

	local n = C.recvfrom(
		self.no, buf, len, 0, ffi.cast("struct sockaddr *", addr), addr_len)

	if n >= 0 then
		return n
	end

	local err = ffi.errno()
	if err ~= errno["EAGAIN"] then
		self:close()
		return n, err
	end

	-- EAGAIN
	local ev = self.r_ev:recv()
	if ev < 0 then
		self:close()
		return -1, errno["EBADF"]
	end

	return self:recvfrom(addr, buf, len)
end


--
-- UDP module interface
--
local UDP_mt = {}
UDP_mt.__index = UDP_mt


function UDP_mt:create()
	-- TODO: refactor sys.socket...
	local no = C.socket(C.AF_INET, C.SOCK_DGRAM, 0)
	if no < 0 then
		error(errno:message(ffi.errno()))
	end
	sys.os.nonblock(no)

	local m = setmetatable({hub = self.hub, no = no}, Socket_mt)
	m.r_ev, m.w_ev = self.hub:register(no, true, true)
	return m
end


function UDP_mt:listen(port, host)
	local no, err = sys.socket.listen(C.AF_INET, C.SOCK_DGRAM, port, host)
	if err then
		error(errno:message(err))
	end
	sys.os.nonblock(no)

	local m = setmetatable({hub = self.hub, no = no}, Socket_mt)
	m.r_ev, m.w_ev = self.hub:register(no, true, true)
	return m
end


return function(hub)
	return setmetatable({hub = hub}, UDP_mt)
end
