local ffi = require("ffi")

local types = {
	OSX     = "ev.kqueue",
	Linux   = "ev.epoll",
	BSD     = "ev.kqueue"
}

return require(types[ffi.os])


