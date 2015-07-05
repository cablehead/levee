local ffi = require('ffi')
local Errno = require('levee.errno')

ffi.cdef[[
static const int EV_POLL_OUT_MAX = 64;
static const int SIGNAL_MAX = 32;
static const int SIZEOF_SIGNALFD_SIGINFO = 128;

typedef struct epoll_event LeveePollerEvent;

struct LeveePoller {
	int fd;
	int tmp[1];
	struct timeval tv;
	struct epoll_event ev[EV_POLL_OUT_MAX];
	int sigs[SIGNAL_MAX];
	char buf[SIZEOF_SIGNALFD_SIGINFO];
};
]]

local C = ffi.C

local LEVEE_POLL_MASK    = 0x0FFFFFFFFULL
local LEVEE_POLL_CHANNEL = 0x100000000ULL
local LEVEE_POLL_SIGNAL  = 0x200000000ULL


local Event = {}
Event.__index = Event

function Event:value()

	if bit.band(LEVEE_POLL_CHANNEL, self.data.u64) > 0 then
		-- channel
		return nil, true

	elseif bit.band(LEVEE_POLL_SIGNAL, self.data.u64) > 0 then
		-- signal
		local no = bit.band(LEVEE_POLL_MASK, self.data.u64)
		return tonumber(no), false, true

	else
		-- io
		local r = bit.band(self.events, C.EPOLLIN) > 0
		local w = bit.band(self.events, C.EPOLLOUT) > 0
		local e = bit.band(self.events, bit.bor(C.EPOLLERR, C.EPOLLHUP)) > 0
		return tonumber(self.data.fd), false, false, r, w, e
	end
end

ffi.metatype("LeveePollerEvent", Event)


local Poller = {}
Poller.__index = Poller


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


function Poller:signal_register(no)
	assert(self.sigs[no] == 0)

	local sigset = ffi.new("sigset_t[1]")
	local rc = C.sigaddset(sigset, no)
	assert(rc == 0)

	local fd = C.signalfd(-1, sigset, 0)
	assert(fd > 0)
	self.sigs[no] = fd

	local ev = self.ev[0]
	ev.events = bit.bor(C.EPOLLET, C.EPOLLERR, C.EPOLLHUP, C.EPOLLIN)
	ev.data.u64 = bit.bor(LEVEE_POLL_SIGNAL, no)
	local rc = C.epoll_ctl(self.fd, C.EPOLL_CTL_ADD, fd, ev)
	if rc < 0 then Errno:error("epoll_ctl") end

	local rc = C.sigprocmask(C.SIG_BLOCK, sigset, nil)
	assert(rc == 0)
end


function Poller:signal_unregister(no)
	assert(self.sigs[no] > 0)

	local sigset = ffi.new("sigset_t[1]")
	local rc = C.sigaddset(sigset, no)
	assert(rc == 0)

	local rc = C.sigprocmask(C.SIG_UNBLOCK, sigset, nil)
	assert(rc == 0)

	C.close(self.sigs[no])
	self.sigs[no] = 0
end


function Poller:signal_clear(no)
	assert(self.sigs[no] > 0)
	C.read(self.sigs[no], self.buf, C.SIZEOF_SIGNALFD_SIGINFO)
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
	ev.data.u64 = fd
	local rc = C.epoll_ctl(self.fd, C.EPOLL_CTL_ADD, fd, ev)
	if rc < 0 then Errno:error("epoll_ctl") end
end


function Poller:unregister(fd)
	-- noop
end


function Poller:poll(timeout)
	local ms = -1
	if timeout then
		if timeout > 0 then
			ms = self:reltime(timeout)
			if ms < 0 then
				ms = 0
			end
		else
			ms = 0
		end
	end

	local n = C.epoll_wait(self.fd, self.ev, 1, ms)

	local err = ffi.errno()

	C.gettimeofday(self.tv, nil)

	if n >= 0 then
		return self.ev, n
	end

	if err ~= Errno["EINTR"] then Errno:error("epoll_wait", err) end

	return self:poll(timeout)
end


function Poller:abstime(rel)
	return rel + ((self.tv.tv_sec * 1000LL) + (self.tv.tv_usec / 1000LL))
end


function Poller:reltime(abs)
	return abs - ((self.tv.tv_sec * 1000LL) + (self.tv.tv_usec / 1000LL))
end


return ffi.metatype("struct LeveePoller", Poller)
