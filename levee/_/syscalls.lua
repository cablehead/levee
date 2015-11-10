local ffi = require("ffi")
local C = ffi.C


local errors = require("levee.errors")


local sockaddr_in = ffi.typeof("struct sockaddr_in")


local Stat_mt = {}
Stat_mt.__index = Stat_mt


function Stat_mt:is_reg()
	return bit.band(self.st_mode, C.S_IFREG) ~= 0
end


function Stat_mt:is_dir()
	return bit.band(self.st_mode, C.S_IFDIR) ~= 0
end


ffi.metatype("struct levee_stat", Stat_mt)


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


local Endpoint_mt = {}
Endpoint_mt.__index = Endpoint_mt


if ffi.os:lower() == "linux" then
	function Endpoint_mt:_set_family(no)
		self.len[0] = ffi.sizeof("int")
		local rc = C.getsockopt(
			no, C.SOL_SOCKET, C.SO_DOMAIN, self.family, self.len)
		if rc < 0 then return errors.get(ffi.errno()) end
	end
else
	function Endpoint_mt:_set_family(no)
		self.family[0] = self.addr.sa.sa_family
	end
end


function Endpoint_mt:__new()
	local m = ffi.new(self)
	m.len[0] = ffi.sizeof(m)
	return m
end


function Endpoint_mt:port()
	if self.family[0] == C.AF_INET then
		return tonumber(C.ntohs(self.addr.sin.sin_port))
	elseif self.family[0] == C.AF_INET6 then
		return tonumber(C.ntohs(self.addr.sin6.sin6_port))
	end
end


function Endpoint_mt:__tostring()
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

local Endpoint = ffi.metatype("struct LeveeEndpoint", Endpoint_mt)


local _ = {}


_.open_modes = {
	["r"]   = C.O_RDONLY,
	["r+"]  = C.O_RDWR,
	["w"]   = bit.bor(C.O_WRONLY, C.O_TRUNC),
	["w+"]  = bit.bor(C.O_RDWR, C.O_CREAT, C.O_TRUNC),
	["a"]   = bit.bor(C.O_WRONLY, C.O_CREAT, C.O_APPEND),
	["a+"]  = bit.bor(C.O_RDWR, C.O_CREAT, C.O_APPEND),
	["rx"]  = bit.bor(C.O_RDONLY, C.O_EXCL),
	["r+x"] = bit.bor(C.O_RDWR, C.O_EXCL),
	["wx"]  = bit.bor(C.O_WRONLY, C.O_TRUNC, C.O_EXCL),
	["w+x"] = bit.bor(C.O_RDWR, C.O_CREAT, C.O_TRUNC, C.O_EXCL),
	["ax"]  = bit.bor(C.O_WRONLY, C.O_CREAT, C.O_APPEND, C.O_EXCL),
	["a+x"] = bit.bor(C.O_RDWR, C.O_CREAT, C.O_APPEND, C.O_EXCL),
}


_.open = function(path, mode, ...)
	if type(mode) == "string" then
		mode = _.open_modes[str]
		if not mode then
			return errors.system.EINVAL
		end
	elseif mode ~= nil then
		mode = bit.bor(mode, ...)
	else
		mode = C.O_RDONLY
	end
	local no = C.open(path, mode)
	if no > 0 then return nil, no, mode end
	return errors.get(ffi.errno())
end


_.pipe = function()
	local fds = ffi.new("int[2]")
	if C.pipe(fds) == 0 then
		return nil, fds[0], fds[1]
	end
	return errors.get(ffi.errno())
end


_.write = function(no, buf, len)
	if not len then
		if type(buf) == "cdata" then
			len = ffi.sizeof(buf)
		else
			len = #buf
		end
	end
	local n = C.write(no, buf, len)
	if n > 0 then return nil, tonumber(n) end
	return errors.get(ffi.errno())
end


_.read = function(no, buf, len)
	if not len then len = ffi.sizeof(buf) end
	local n = C.read(no, buf, len)
	if n >= 0 then return nil, tonumber(n) end
	return errors.get(ffi.errno())
end


_.reads = function(no, len)
	len = len or 4096
	local buf = ffi.new("char[?]", len)
	local err, n = _.read(no, buf, len)
	if err then return end
	return ffi.string(buf, n)
end


_.close = function(no)
	local rc = C.close(no)
	if rc ~= 0 then return errors.get(ffi.errno()) end
end


_.stat = function(path)
	local info = ffi.new("struct levee_stat")
	local rc = C.levee_stat(path, info)
	if rc == 0 then return nil, info end
	return errors.get(ffi.errno())
end


_.fstat = function(no)
	local info = ffi.new("struct levee_stat")
	local rc = C.levee_fstat(no, info)
	if rc == 0 then return nil, info end
	return errors.get(ffi.errno())
end


_.fcntl = function(no, cmd, ...)
	local rc = C.fcntl(no, cmd, ...)
	if rc ~= -1 then return nil, rc end
	return errors.get(ffi.errno())
end


_.fcntl_nonblock = function(no)
		local err, flags = _.fcntl(no, C.F_GETFL)
		if err then return err end
		local nflags = bit.bor(flags, C.O_NONBLOCK)
		if nflags == flags then return end
		local err = _.fcntl(no, C.F_SETFL, ffi.new("int", nflags))
		if err then return err end
end


_.fcntl_block = function(no)
		local err, flags = _.fcntl(no, C.F_GETFL)
		if err then return err end
		local nflags = bit.band(flags, bit.bnot(C.O_NONBLOCK))
		if nflags == flags then return end
		local err = _.fcntl(no, C.F_SETFL, ffi.new("int", nflags))
		if err then return err end
end


_.getaddrinfo = function(host, port)
	local hints = ffi.new("struct addrinfo")
	hints.ai_family = C.AF_INET
	-- TODO: do we really want SOCK_STREAM as a hint here
	hints.ai_socktype = C.SOCK_STREAM
	local info = ffi.new("struct addrinfo *[1]")

	local rc = C.getaddrinfo(host, port, hints, info)
	if rc ~= 0 then return errors.get_eai(rc) end

	return nil, info[0], ffi.new("struct addrinfo *", info[0])
end


_.getsockname = function(no)
	local ep = Endpoint()
	local rc = C.getsockname(no, ep.addr.sa, ep.len)
	if rc < 0 then return errors.get(ffi.errno()) end
	local err = ep:_set_family(no)
	if err then return err end
	return nil, ep
end


_.getpeername = function(no)
	local ep = Endpoint()
	local rc = C.getpeername(no, ep.addr.sa, ep.len)
	if rc < 0 then return errors.get(ffi.errno()) end
	local err = ep:_set_family(no)
	if err then return err end
	return nil, ep
end


_.listen = function(domain, type_, host, port)
	local BACKLOG = 256
	-- TODO: should we be using getaddrinfo here?
	host = host or "127.0.0.1"
	port = port or 0

	local no = C.socket(domain, type_, 0)
	if no < 0 then return errors.get(ffi.errno()) end

	local on = ffi.new("int32_t[1]", 1)
	local rc = C.setsockopt(no, C.SOL_SOCKET, C.SO_REUSEADDR, on, ffi.sizeof(on))
	if rc < 0 then return errors.get(ffi.errno()) end

	local addr = sockaddr_in()
	addr.sin_family = domain
	addr.sin_port = C.htons(port);
	C.inet_aton(host, addr.sin_addr)

	rc = C.bind(no, ffi.cast("struct sockaddr *", addr), ffi.sizeof(addr))
	if rc < 0 then return errors.get(ffi.errno()) end

	if type_ == C.SOCK_STREAM then
		rc = C.listen(no, BACKLOG)
		if rc < 0 then return errors.get(ffi.errno()) end
	end

	return nil, no
end


_.connect = function(host, port)
	local no = C.socket(C.PF_INET, C.SOCK_STREAM, 0)
	if no < 0 then return errors.get(ffi.errno()) end

	local err, info, ptr = _.getaddrinfo(host, tostring(port))
	if err then return err end

	local err
	while ptr ~= nil do
		local rc = C.connect(no, ptr.ai_addr, ptr.ai_addrlen)
		if rc == 0 then break end
		err = ffi.errno()
		ptr = ptr.ai_next
	end

	C.freeaddrinfo(info)

	if ptr ~= nil then
		return nil, no
	end

	return errors.get(err)
end


_.accept = function(no)
	local addr = sockaddr_in()
	local addr_len = ffi.new("socklen_t[1]")
	local no = C.accept(no, ffi.cast("struct sockaddr *", addr), addr_len)
	if no < 0 then return errors.get(ffi.errno()) end
	return nil, no
end


return _
