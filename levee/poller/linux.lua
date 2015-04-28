require('ev.cdef')

local ffi = require('ffi')
local errno = require('levee.errno')

ffi.cdef[[
static const int EV_POLL_OUT_MAX = 64;
struct LeveePoller {
	int fd;
	int tmp[1];
	struct epoll_event ev[EV_POLL_OUT_MAX];
};
]]

local C = ffi.C

local Poller = {}
Poller.__index = Poller


function Poller:new()
	local self = self.allocate(C.epoll_create1(0))
	if self.fd < 0 then errno.error("epoll_create1") end
	return self
end


function Poller:__gc()
	C.close(self.fd)
end


function Poller:register(fd)
	local ev = self.ev[0]
	ev.events = bit.bor(C.EPOLLIN, C.EPOLLET)
	ev.data.fd = fd

	local rc = C.epoll_ctl(self.fd, C.EPOLL_CTL_ADD, fd, ev)
	if rc < 0 then errno.error("epoll_ctl") end

	return tonumber(fd)
end


function Poller:poll()
	--local n = C.epoll_wait(self.fd, self.ev, EV_POLL_OUT_MAX, -1)
	local n = C.epoll_wait(self.fd, self.ev, 1, -1)
	if n < 0 then errno.error("epoll_wait") end

	print("poll got:", n)
	self.tmp[0] = 0
	local fd = self.ev[0].data.fd
	-- TODO don't call on listening sockets
	C.ioctl(fd, C.FIONREAD, ffi.cast("int *", self.tmp))
	return tonumber(fd), self.tmp[0]
end


Poller.allocate = ffi.metatype("struct LeveePoller", Poller)

return Poller
