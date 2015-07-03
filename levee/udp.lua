local ffi = require("ffi")
local C = ffi.C

local errno = require("levee.errno")
local sys = require("levee.sys")


--
-- UDP module interface
--
local UDP_mt = {}
UDP_mt.__index = UDP_mt


function UDP_mt:create()
end


function UDP_mt:listen(port, host)
	local no, err = sys.socket.listen(C.AF_INET, C.SOCK_DGRAM, port, host)
	if err then
		error(errno:message(err))
	end
	sys.os.nonblock(no)
	return no
end


return function(hub)
	return setmetatable({hub = hub}, UDP_mt)
end
