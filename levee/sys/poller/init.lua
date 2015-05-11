local ffi = require("ffi")
return {
	POLLIN = 1,
	POLLOUT = 2,
	POLLERR = 3,
	Poller = require("levee.sys.poller." .. ffi.os:lower()), }
