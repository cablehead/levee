--
-- TODO: what a mess. just bashing this out.
--

local message = require("levee.message")
local sys = require("levee.sys")


local Recver = function(hub, pollin, no)
	local sender, recver = unpack(hub:pipe())

	hub:spawn(function()
		while true do
			local got = pollin:recv()
			if got == nil then
				hub:unregister(no)
				sender:close()
				break
			end

			while true do
				local s = sys.fd.reads(no)
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
			hub:unregister(no)
			return recver:close()
		end,
	}
end


local Sender = function(hub, pollout, no)
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
				hub:unregister(no)
				break
			end
			if sys.fd.write(no, s) < 0 then
				recver:close()
				hub:unregister(no)
				break
			end
		end
	end)

	return sender
end


return function(hub)
	local M = {h=hub}

	function M:r(no)
		sys.fd.nonblock(no, true)
		local pollin = self.h:register(no, true)
		return Recver(hub, pollin, no)
	end

	function M:w(no)
		sys.fd.nonblock(no, true)
		local _, pollout = self.h:register(no, nil, true)
		return Sender(hub, pollout, no)
	end


	function M:rw(no)
		sys.fd.nonblock(no, true)
		local pollin, pollout = self.h:register(no, true, true)
		local recver = Recver(hub, pollin, no)
		local sender = Sender(hub, pollout, no)
		return message.Pair(sender, recver)
	end

	function M:pipe()
	end

	return M
end
