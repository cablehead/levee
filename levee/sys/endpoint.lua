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
	socklen_t len[1];
	int family[1];
};
]]

local C = ffi.C

local Endpoint = {}
Endpoint.__index = Endpoint


local set_family

if ffi.os:lower() == "linux" then
	set_family = function(ep, fd)
		ep.len[0] = ffi.sizeof("int")
		return C.getsockopt(fd, C.SOL_SOCKET, C.SO_DOMAIN, ep.family, ep.len)
	end
else
	set_family = function(ep, fd)
		ep.family[0] = ep.addr.sa.sa_family
		return 0
	end
end


function Endpoint:__new()
	-- TODO add URI endpoint to sockaddr
	return ffi.new(self)
end


function Endpoint:sockname(fd)
	local ep = ffi.new(self)
	ep.len[0] = ffi.sizeof(ep)
	local rc = C.getsockname(fd, ep.addr.sa, ep.len)
	if rc < 0 or set_family(ep, fd) < 0 then
		return nil, ffi.errno()
	end
	return ep, 0
end


function Endpoint:peername(fd)
	local ep = ffi.new(self)
	ep.len[0] = ffi.sizeof(ep)
	local rc = C.getpeername(fd, ep.addr.sa, ep.len)
	if rc < 0 or set_family(ep, fd) < 0 then
		return nil, ffi.errno()
	end
	return ep, 0
end


function Endpoint:port()
	if self.family[0] == C.AF_INET then
		return tonumber(C.ntohs(self.addr.sin.sin_port))
	elseif self.family[0] == C.AF_INET6 then
		return tonumber(C.ntohs(self.addr.sin6.sin6_port))
	end
end


function Endpoint:__tostring()
	if self.family[0] == C.AF_INET then
		local buf = ffi.new("char [16]")
		local str = C.inet_ntop(C.AF_INET, self.addr.sin.sin_addr, buf, 16)
		if str then
			return string.format(
				"%s:%d", ffi.string(buf), tonumber(C.ntohs(self.addr.sin.sin_port)))
		end
	elseif self.family[0] == C.AF_INET6 then
		local buf = ffi.new("char [48]")
		local str = C.inet_ntop(C.AF_INET6, self.addr.sin6.sin6_addr, buf, 48)
		if str then
			return string.format(
				"[%s]:%d", ffi.string(buf), tonumber(C.ntohs(self.addr.sin6.sin6_port)))
		end
	elseif self.family[0] == C.AF_LOCAL then
		return ffi.string(self.addr.sun.sun_path)
	else
		return string.format("levee.Endpoint: %p", self)
	end
end


return ffi.metatype("struct LeveeEndpoint", Endpoint)
