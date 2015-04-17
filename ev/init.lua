local ffi = require("ffi")


local types = {
	OSX     = "ev/cdef/kqueue",
	Linux   = "ev/cdef/epoll",
	BSD     = "ev/cdef/kqueue"
}
-- return require(types[ffi.os])


local M = {
	tcp = require("ev/tcp"),
}

return M
