require('ev.cdef')

local ffi = require('ffi')
local errno = require('ev.errno')

ffi.cdef[[
static const int EV_POLL_OUT_MAX = 64;
struct EVPoller {
	int fd;
	struct epoll_event ev[EV_POLL_OUT_MAX];
};
]]

local C = ffi.C

local mt = {}
mt.__index = mt

function mt:__gc()
	C.close(self.fd)
end

function mt:register(fd)
	local ev = self.ev[0]
	ev.events = bit.bor(C.EPOLLIN, C.EPOLLET)
	ev.data.fd = fd

	local rc = C.epoll_ctl(self.fd, C.EPOLL_CTL_ADD, fd, ev)
	if rc < 0 then errno.error("epoll_ctl") end

	return tonumber(fd)
end


function mt:poll()
	--local n = C.epoll_wait(self.fd, self.ev, EV_POLL_OUT_MAX, -1)
	local n = C.epoll_wait(self.fd, self.ev, 1, -1)
	if n < 0 then errno.error("epoll_wait") end

	print("poll got:", n)
	return tonumber(self.ev[0].data.fd)
end


local Poller = ffi.metatype("struct EVPoller", mt)

return function()
	local self = Poller(C.epoll_create1(0))
	if self.fd < 0 then errno.error("epoll_create1") end
	return self
end
