local ffi = require("ffi")
local C = ffi.C

local buf_len = C.NI_MAXHOST
local buf = ffi.new("char [?]", buf_len)


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


function Endpoint_mt:host()
	if self.family[0] == C.AF_INET then
		if C.inet_ntop(C.AF_INET, self.addr.sin.sin_addr, buf, buf_len) then
			return ffi.string(buf)
		end
	elseif self.family[0] == C.AF_INET6 then
		if C.inet_ntop(C.AF_INET6, self.addr.sin6.sin6_addr, buf, buf_len) then
			return ffi.string(buf)
		end
	end
end


function Endpoint_mt:port()
	if self.family[0] == C.AF_INET then
		return tonumber(C.ntohs(self.addr.sin.sin_port))
	elseif self.family[0] == C.AF_INET6 then
		return tonumber(C.ntohs(self.addr.sin6.sin6_port))
	end
end


function Endpoint_mt:path()
	if self.family[0] == C.AF_LOCAL then
		return ffi.string(self.addr.sun.sun_path)
	end
end


function Endpoint_mt:name(full)
	local path = self:path()
	if path then return path end

	local flags = 0
	if not full then
		flags = bit.bor(flags, C.NI_NOFQDN)
	end

	local rc = C.getnameinfo(
		self.addr.sa, ffi.sizeof(self.addr.ss), buf, buf_len,
		nil, 0, flags);

	if rc < 0 then
		return self:host()
	else
		return ffi.string(buf)
	end
end


function Endpoint_mt:__tostring()
	if self.family[0] == C.AF_INET then
		local host = self:host()
		if host then return string.format("%s:%d", host, self:port()) end
	elseif self.family[0] == C.AF_INET6 then
		local host = self:host()
		if host then return string.format("[%s]:%d", host, self:port()) end
	elseif self.family[0] == C.AF_LOCAL then
		return self:path()
	end
	return string.format("levee.Endpoint: %p", self)
end


local Endpoint = ffi.metatype("struct LeveeEndpoint", Endpoint_mt)


local _ = {}


_.pagesize = C.getpagesize()


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
		mode = _.open_modes[mode]
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
		return fds[0], fds[1]
	end
	errors.get(ffi.errno()):abort()
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
	if err or n == 0 then return end
	return ffi.string(buf, n)
end


_.sendfile = function(from, to, len, off)
	local n = C.levee_sendfile(to, from, off or 0, len)
	if n >= 0 then return nil, tonumber(n) end
	return errors.get(ffi.errno())
end


if ffi.os:lower() == "linux" then
	_.splice = function(from, to, len, more)
		local flags = bit.bor(C.SPLICE_F_MOVE, C.SPLICE_F_NONBLOCK)
		if more then
			flags = bit.bor(flags, C.SPLICE_F_MORE)
		end
		local n = C.splice(from, nil, to, nil, len, flags)
		if n >= 0 then return nil, tonumber(n) end
		return errors.get(ffi.errno())
	end

	_.tee = function(from, to, len, more)
		local flags = bit.bor(C.SPLICE_F_MOVE, C.SPLICE_F_NONBLOCK)
		if more then
			flags = bit.bor(flags, C.SPLICE_F_MORE)
		end
		local n = C.tee(from, to, len, flags)
		if n >= 0 then return nil, tonumber(n) end
		return errors.get(ffi.errno())
	end
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


_.gethostname = function()
	local rc = C.gethostname(buf, buf_len)
	if rc < 0 then return errors.get(ffi.errno()) end
	return nil, ffi.string(buf)
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


_.accept = function(no)
	local addr = sockaddr_in()
	local addr_len = ffi.new("socklen_t[1]")
	local no = C.accept(no, ffi.cast("struct sockaddr *", addr), addr_len)
	if no < 0 then return errors.get(ffi.errno()) end
	return nil, no
end


_.getrusage = function(who)
	who = who or C.RUSAGE_SELF
	local rusage = ffi.new("struct rusage")
	local rc = C.getrusage(who, rusage)
	if rc < 0 then return errors.get(ffi.errno()) end
	return nil, rusage
end


_.getcurrentrss = function()
	local rss = C.levee_getcurrentrss()
	return nil, rss
end


return _
