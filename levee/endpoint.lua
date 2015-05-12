require("levee.cdef")

local ffi = require("ffi")

ffi.cdef[[
struct LeveeEndpoint {
	union {
		struct sockaddr sa;
		struct sockaddr_storage ss;
		struct sockaddr_in sin;
		struct sockaddr_in6 sin6;
		struct sockaddr_un sun;
	} addr;
};
]]

local C = ffi.C

local Endpoint = {}
Endpoint.__index = Endpoint


function Endpoint:__new()
	-- TODO add URI endpoint to sockaddr
	return ffi.new(self)
end


function Endpoint:sockname(fd)
	local ep = ffi.new(self)
	local len = ffi.new("socklen_t[1]")
	len[0] = ffi.sizeof(ep)
	local rc = C.getsockname(fd, ep.addr.sa, len)
	if rc < 0 then
		return nil, ffi.errno()
	end
	return ep, 0
end


function Endpoint:peername(fd)
	local ep = ffi.new(self)
	local len = ffi.new("socklen_t[1]")
	len[0] = ffi.sizeof(ep)
	local rc = C.getpeername(fd, ep.addr.sa, len)
	if rc < 0 then
		return nil, ffi.errno()
	end
	return ep, 0
end


function Endpoint:__tostring()
	if self.addr.sa.sa_family == C.AF_INET then
		local buf = ffi.new("char [16]")
		local str = C.inet_ntop(C.AF_INET, self.addr.sin.sin_addr, buf, 16)
		if str then
			return string.format("%s:%d", ffi.string(buf), tonumber(C.ntohs(self.addr.sin.sin_port)))
		end
	elseif self.addr.sa.sa_family == C.AF_INET6 then
		local buf = ffi.new("char [48]")
		local str = C.inet_ntop(C.AF_INET6, self.addr.sin6.sin6_addr, buf, 48)
		if str then
			return string.format("[%s]:%d", ffi.string(buf), tonumber(C.ntohs(self.addr.sin6.sin6_port)))
		end
	elseif self.addr.sa.sa_family == C.AF_LOCAL then return ffi.string(self.addr.sun.sun_path) else
		return string.format("levee.Endpoint: %p", self)
	end
end


return ffi.metatype("struct LeveeEndpoint", Endpoint)
