local ffi = require("ffi")
local C = ffi.C


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
		return Recver(self.hub, no)
	end

	return M
end
