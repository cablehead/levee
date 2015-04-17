local socket = require("ev/cdef/socket")
local ffi = require("ffi")
local C = ffi.C


local FD = {}

function FD:new(no)
	local T = {no = no}
	setmetatable(T, self)
	self.__index = self
	return T
end

function FD:send(str)
	return C.write(self.no, str, #str)
end

function FD:recv()
	local BUFSIZE = 8192
	local buf = ffi.new("uint8_t[?]", BUFSIZE)
	local bytes_read = C.read(self.no, buf, ffi.sizeof(buf))
	local response = ffi.string(buf, bytes_read)
	return response
end

function FD:close()
	rc = C.close(self.no)
	assert(rc == 0)
end



local M = {}

M.connect = function(port, host)
	host = host or "127.0.0.1"

	local fd = C.socket(C.AF_INET, C.SOCK_STREAM, 0)
	print("fd", fd, "type(fd)", type(fd))

	local addr = ffi.new("struct sockaddr_in[1]")
	addr[0].sin_family = C.AF_INET
	addr[0].sin_port = C.htons(port);
	C.inet_aton(host, addr[0].sin_addr)

	local rc = C.connect(fd, ffi.cast("struct sockaddr *", addr), ffi.sizeof(addr))
	assert(rc == 0)

	return FD:new(fd)
end

return M
