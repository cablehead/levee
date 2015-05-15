local ffi = require("ffi")
local FD = require("levee.fd")
local Endpoint = require("levee.endpoint")

ffi.cdef[[
struct LeveeSocket {
	struct LeveeFD base;
	union {
		socklen_t socklen[1];
		int intval[1];
	} tmp;
	bool listening;
};
]]

local C = ffi.C


local sockaddr_in = ffi.typeof("struct sockaddr_in")


local Socket = {}
Socket.__index = Socket


function Socket:__new(no, listening)
	local sock = ffi.new(self)
	sock.base.no = no
	sock.listening = listening
	sock.base:nonblock(true)
	return sock
end


function Socket:connect(port, host)
	local no = C.socket(C.PF_INET, C.SOCK_STREAM, 0)
	if no < 0 then return nil, ffi.errno() end

	local addr = sockaddr_in()
	addr.sin_family = C.AF_INET
	addr.sin_port = C.htons(port);
	C.inet_aton(host or "0.0.0.0", addr.sin_addr)

	local rc = C.connect(no, ffi.cast("struct sockaddr *", addr), ffi.sizeof(addr))
	if rc < 0 then return nil, ffi.errno() end

	return Socket.__new(self, no, false), 0
end


function Socket:listen(port, host, backlog)
	local no = C.socket(C.PF_INET, C.SOCK_STREAM, 0)
	if no < 0 then return nil, ffi.errno() end

	local on = ffi.new("int32_t[1]", 1)
	local rc = C.setsockopt(no, C.SOL_SOCKET, C.SO_REUSEADDR, on, ffi.sizeof(on))
	if rc < 0 then return nil, ffi.errno() end

	local addr = sockaddr_in()
	addr.sin_family = C.AF_INET
	addr.sin_port = C.htons(port);
	C.inet_aton(host or "0.0.0.0", addr.sin_addr)
	rc = C.bind(no, ffi.cast("struct sockaddr *", addr), ffi.sizeof(addr))
	if rc < 0 then return nil, ffi.errno() end

	rc = C.listen(no, backlog or 256)
	if rc < 0 then return nil, ffi.errno() end

	return Socket.__new(self, no, true), 0
end


function Socket:__tostring()
	local sock = Endpoint:sockname(self.base.no)
	if self.listening then
		return string.format("levee.Socket: %d, %s", self.base.no, sock)
	else
		local peer = Endpoint:peername(self.base.no)
		return string.format("levee.Socket: %d, %s->%s", self.base.no, sock, peer)
	end
end


function Socket:__gc()
	self.base:__gc()
end


function Socket:accept()
	local addr = sockaddr_in()
	local no = C.accept(self.base.no, ffi.cast("struct sockaddr *", addr), self.tmp.socklen)
	if no < 0 then
		return nil, ffi.errno()
	end
	return Socket(no, false)
end


function Socket:available()
	if self.listening then
		-- TODO figure out accept count?
		return 0ULL
	else
		C.ioctl(self.base.no, C.FIONREAD, ffi.cast("int *", self.tmp.intval))
		return self.tmp.intval[0]
	end
end


function Socket:read(buf, len)
	return self.base:read(buf, len)
end


function Socket:write(buf, len)
	return self.base:write(buf, len)
end


return ffi.metatype("struct LeveeSocket", Socket)
