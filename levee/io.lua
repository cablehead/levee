--
-- TODO: what a mess. just bashing this out.
--

local sys = require("levee.sys")


local Recver = function(hub, pollin, fd)
	local sender, recver = unpack(hub:pipe())

	hub:spawn(function()
		while true do
			local got = pollin:recv()
			if got == nil then
				hub:unregister(fd.no)
				sender:close()
				break
			end

			while true do
				local s = fd:reads()
				if s == nil then break end
				sender:send(s)
			end
		end
	end)

	return {
		recv = function()
			return recver:recv()
		end,

		close = function()
			hub:unregister(fd.no)
			return recver:close()
		end,
	}
end


local Sender = function(hub, pollout, fd)
	local sender, recver = unpack(hub:pipe())
	local gate = hub:switch()

	hub:spawn(function()
		while true do
			local s = pollout:recv()
			if s == nil then
				gate.sender:close()
				recver:close()
				break
			end
			gate.sender:send(s)
		end
	end)

	hub:spawn(function()
		while true do
			local s = recver:recv()
			if s == nil then
				hub:unregister(fd.no)
				break
			end
			if fd:write(s) < 0 then
				recver:close()
				hub:unregister(fd.no)
				break
			end
		end
	end)

	return sender
end


return function(hub)
	local M = {h=hub}

	function M:r(no)
		local fd = sys.fd.FD(no)
		fd:nonblock(true)
		local pollin = self.h:register(no, true)
		return Recver(hub, pollin, fd)
	end

	function M:w(no)
		local fd = sys.fd.FD(no)
		fd:nonblock(true)
		local _, pollout = self.h:register(no, nil, true)
		return Sender(hub, pollout, fd)
	end


	function M:rw(no)
	end

	function M:pipe()
	end

	return M
end
