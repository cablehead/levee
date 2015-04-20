require("ev.cdef.socket")
require("ev.cdef.fcntl")

local ffi = require("ffi")
local C = ffi.C


function unblock(fd)
  local flags = C.fcntl(fd, C.F_GETFL, 0)
  if flags == -1 then
    return -1
  end

  flags = bit.bor(flags, C.O_NONBLOCK)
  local rc = C.fcntl(fd, C.F_SETFL, ffi.new("int", flags))
  if rc == -1 then
    return -1
  end
  return 0
end


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
	print("BYTES_READ", bytes_read)
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
	local on = ffi.new("int32_t[1]", 1)
	local rc = C.setsockopt(
		self.no, C.SOL_SOCKET, C.SO_REUSEADDR, on, ffi.sizeof(on))
	assert(rc == 0)

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

	local rc = unblock(no)
	assert(rc == 0)

	return no
end




return function(hub)
	-- todo, turn this into an object, just bashing this out
	local M = {hub=hub}

	function M:connect(port, host)
		local socket = Socket:new()
		socket:connect(host or "127.0.0.1", port)
		return FD:new(socket.no)
	end


	function M:listen(port, host)
		local socket = Socket:new()
		socket:bind(host or "0.0.0.0", port or 0)

		local ready = self.hub:register(socket.no)
		local connections = self.hub:pipe()

		self.hub:spawn(function()
			while true do
				ready:recv()
				local no = socket:accept()
				local conn = self.hub.io:fd_in(no)
				connections:send(conn)
			end
		end)

		return connections
	end

	return M
end
