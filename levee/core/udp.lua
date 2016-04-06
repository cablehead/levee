local ffi = require("ffi")
local C = ffi.C

local errors = require("levee.errors")
local _ = require("levee._")
local Dialer = require("levee.core.dialer")


--
-- UDP module interface
--
local UDP_mt = {}
UDP_mt.__index = UDP_mt


function UDP_mt:dial(port, host)
	if not self.dialer then
		self.dialer = self.hub:pool(function()
			return Dialer(self.hub, C.SOCK_DGRAM)
		end, 1)
	end
	local err, no = self.dialer:run(function(dialer)
		return dialer:dial(host, port)
	end)
	if err then return err end
	_.fcntl_nonblock(no)
	return nil, self.hub.io:w(no)
end


function UDP_mt:listen(port, host)
	local err, no = _.listen(C.AF_INET, C.SOCK_DGRAM, host, port)
	if err then return err end
	_.fcntl_nonblock(no)
	return nil, self.hub.io:r(no)
end


return function(hub)
	return setmetatable({hub = hub}, UDP_mt)
end
