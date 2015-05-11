local ffi = require('ffi')
local Errno = require('levee.errno')

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


local POLLIN = 1
local POLLOUT = 2
local POLLERR = 3


function Poller:__new()
	local self = ffi.new(self, C.epoll_create1(0))
	if self.fd < 0 then Errno:error("epoll_create1") end
	return self
end


function Poller:__tostring()
	return string.format("levee.Poller(epoll): %d", self.fd)
end


function Poller:__gc()
	C.close(self.fd)
end


function Poller:register(fd, r, w)
	local ev = self.ev[0]
	ev.events = bit.bor(C.EPOLLET, C.EPOLLERR, C.EPOLLHUP)
	if r then
		ev.events = bit.bor(ev.events, C.EPOLLIN)
	end
	if w then
		ev.events = bit.bor(ev.events, C.EPOLLOUT)
	end
	ev.data.fd = fd
	local rc = C.epoll_ctl(self.fd, C.EPOLL_CTL_ADD, fd, ev)
	if rc < 0 then Errno:error("epoll_ctl") end
end


function Poller:unregister(fd)
	local rc = C.epoll_ctl(self.fd, C.EPOLL_CTL_DEL, fd, nil)
	if rc >= 0 then
		C.close(fd)
	end
end


function Poller:poll()
	--local n = C.epoll_wait(self.fd, self.ev, EV_POLL_OUT_MAX, -1)
	local n = C.epoll_wait(self.fd, self.ev, 1, -1)
	if n < 0 then Errno:error("epoll_wait") end

	local fd = tonumber(self.ev[0].data.fd)

	if bit.band(self.ev[0].events, bit.bor(C.EPOLLERR, C.EPOLLHUP)) > 0 then
		return fd, POLLERR
	end

	if bit.band(self.ev[0].events, C.EPOLLIN) > 0 then
		return fd, POLLIN
	end

	if bit.band(self.ev[0].events, C.EPOLLOUT) > 0 then
		return fd, POLLOUT
	end
end


return ffi.metatype("struct LeveePoller", Poller)
