local sys = require("levee.sys")

local ffi = require("ffi")
local C = ffi.C


return function(hub)
	-- todo, turn this into an object, just bashing this out
	local M = {hub=hub}

	function M:connect(port, host)
		local no = sys.socket.connect(port, host or "127.0.0.1")
		return hub.io:rw(no)
	end

	function M:listen(port, host)
		local no = sys.socket.listen(port, host)

		local ready = self.hub:register(no, true)
		local sender, recver = unpack(self.hub:pipe())

		self.hub:spawn(function()
			while true do
				ready:recv()
				local no = sys.socket.accept(no)
				local conn = hub.io:rw(no)
				sender:send(conn)
			end
		end)

		return {
			recv = function()
				return recver:recv()
			end,

			close = function()
				hub:unregister(no)
				return recver:close()
			end,
		}
	end

	return M
end
