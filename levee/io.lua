require("levee.cdef")

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

function FD:read()
	local BUFSIZE = 8192
	local buf = ffi.new("uint8_t[?]", BUFSIZE)
	local bytes_read = C.read(self.no, buf, ffi.sizeof(buf))
	if bytes_read <= 0 then
		return bytes_read
	end
	local response = ffi.string(buf, bytes_read)
	return bytes_read, response
end

function FD:write(s)
	-- TODO: handle EAGAIN
	return C.write(self.no, s, #s)
end

function FD:close()
	rc = C.close(self.no)
	assert(rc == 0)
end

function Recver(hub, no)
	local ready = hub:register(no)
	local fd = FD:new(no)
	local pipe = hub:pipe()

	hub:spawn(function()
		while true do
			ready:recv()
			while true do
				n, data = fd:read()
				if n < 0 then
					print("IO RECV LOOP", ffi.errno())
					break
				elseif n == 0 then
					print("IO RECV CLOSE")
					pipe:close()
					return
				end
				pipe:send(data)
			end
		end
	end)

	return pipe
end


return function(hub)
	local M = {hub=hub}

	function M:fd_in(no)
		local rc = unblock(no)
		assert(rc == 0)
		return Recver(self.hub, no)
	end

	return M
end
