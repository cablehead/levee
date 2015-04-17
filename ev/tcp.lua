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



local Socket = {}


function Socket:new()
	local T = {}
	setmetatable(T, self)
	self.__index = self
	T.no = C.socket(C.AF_INET, C.SOCK_STREAM, 0)
	return T
end


function Socket:connect(host, port)
	local addr = ffi.new("struct sockaddr_in[1]")
	addr[0].sin_family = C.AF_INET
	addr[0].sin_port = C.htons(port);
	C.inet_aton(host, addr[0].sin_addr)
	local rc = C.connect(
		self.no, ffi.cast("struct sockaddr *", addr), ffi.sizeof(addr))
	assert(rc == 0)
end


function Socket:bind(host, port)
	local addr = ffi.new("struct sockaddr_in[1]")
	addr[0].sin_family = C.AF_INET
	addr[0].sin_port = C.htons(port);
	C.inet_aton(host or "0.0.0.0", addr[0].sin_addr)
	rc = C.bind(self.no, ffi.cast("struct sockaddr *", addr), ffi.sizeof(addr))
	assert(rc == 0)

	rc = C.listen(self.no, 128)
	assert(rc == 0)
end


function Socket:accept()
	local peer_addr = ffi.new("struct sockaddr_in[1]")
	local peer_addr_size = ffi.new("int32_t[1]")
	local no = C.accept(
		self.no, ffi.cast("struct sockaddr *", peer_addr), peer_addr_size)
	assert(no >= 0)
	return FD:new(no)
end



local M = {}


M.connect = function(port, host)
	local socket = Socket:new()
	socket:connect(host or "127.0.0.1", port)
	return FD:new(socket.no)
end


M.listen = function(port, host)
	local socket = Socket:new()
	socket:bind(host or "0.0.0.0", port or 0)
	return socket
end


return M
