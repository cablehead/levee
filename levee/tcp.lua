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
		sys.fd.nonblock(no, true)

		local ready = self.hub:register(no, true)
		local sender, recver = unpack(self.hub:pipe())

		self.hub:spawn(function()
			for _ in ready do
				while true do
					local no, err = sys.socket.accept(no)
					-- TODO: only break on EAGAIN, should close on other errors
					if no == nil then break end
					local conn = hub.io:rw(no)
					sender:send(conn)
				end
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
