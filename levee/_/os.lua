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


local _ = {}


_.open = function(path, ...)
	local no = C.open(path, bit.bor(...))
	if no > 0 then return nil, no end
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
	if n > 0 then return nil, tonumber(n) end
	return errors.get(ffi.errno())
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


_.reads = function(no, len)
	len = len or 4096
	local buf = ffi.new("char[?]", len)
	local err, n = _.read(no, buf, len)
	if err then return err end
	return nil, ffi.string(buf, n)
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

	-- TODO: segfaults
	if rc ~= 0 then return errors.get(rc) end
	assert(rc == 0)

	return nil, info[0], ffi.new("struct addrinfo *", info[0])
end


_.listen = function(domain, type_, host, port)
	local BACKLOG = 256
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


return _
