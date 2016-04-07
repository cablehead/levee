local _ = require("levee._")


local UDP_mt = {}
UDP_mt.__index = UDP_mt


function UDP_mt:dial(port, host)
	local err, no = self.hub.dialer:dial(C.AF_INET, C.SOCK_DGRAM, host, port)
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
