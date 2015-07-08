local ffi = require('ffi')
local Errno = require('levee.errno')

ffi.cdef[[
static const int EV_POLL_IN_MAX = 64;
static const int EV_POLL_OUT_MAX = 64;

typedef struct kevent LeveePollerEvent;

struct LeveePoller {
	int fd;
	int ev_in_pos;
	uintptr_t id;
	struct timeval tv;
	struct timespec ts;
	struct kevent ev_in[EV_POLL_IN_MAX];
	LeveePollerEvent ev_out[EV_POLL_OUT_MAX];
};
]]

local C = ffi.C


local Event = {}
Event.__index = Event

function Event:value()
	local fd = tonumber(self.ident)
	local r = self.filter == C.EVFILT_READ
	local w = self.filter == C.EVFILT_WRITE
	local e = bit.band(self.flags, bit.bor(C.EV_EOF, C.EV_ERROR)) > 0
	return fd, r, w, e
end

ffi.metatype("LeveePollerEvent", Event)


local Poller = {}
Poller.__index = Poller


function Poller:__new()
	local self = ffi.new(self, C.kqueue(), 0, 0)
	if self.fd < 0 then Errno:error("kqueue") end
	C.gettimeofday(self.tv, nil)
	return self
end


function Poller:__tostring()
	return string.format("levee.Poller(kqueue): %d", self.fd)
end


function Poller:__gc()
	C.close(self.fd)
end


local function next_event(self)
	if self.ev_in_pos == C.EV_POLL_IN_MAX then
		-- flush pending events if the list is full
		local rc = C.kevent(self.fd, self.ev_in, C.EV_POLL_IN_MAX, nil, 0, nil)
		if rc < 0 then Errno:error("kevent") end
		self.ev_in_pos = 0
	end
	local ev = self.ev_in[self.ev_in_pos]
	self.ev_in_pos = self.ev_in_pos + 1
	return ev
end


function Poller:register(fd, r, w)
	if r then
		local ev = next_event(self)
		ev.ident = fd
		ev.filter = C.EVFILT_READ
		ev.flags = bit.bor(C.EV_ADD, C.EV_CLEAR)
		ev.fflags = 0
		ev.data = 0
	end

	if w then
		local ev = next_event(self)
		ev.ident = fd
		ev.filter = C.EVFILT_WRITE
		ev.flags = bit.bor(C.EV_ADD, C.EV_CLEAR)
		ev.fflags = 0
		ev.data = 0
	end
end

function Poller:unregister(fd, r, w)
	-- noop
end


function Poller:poll(timeout)
	local ts = nil
	if timeout then
		if timeout > 0 then
			local ms = self:reltime(timeout)
			if ms < 0 then
				self.ts.tv_sec = 0
				self.ts.tv_nsec = 0
			else
				self.ts.tv_sec = (ms / 1000LL)
				self.ts.tv_nsec = (ms % 1000LL) * 1000000LL
			end
		else
			self.ts.tv_sec = 0
			self.ts.tv_nsec = 0
		end
		ts = self.ts
	end

	local n = C.kevent(
		self.fd, self.ev_in, self.ev_in_pos, self.ev_out, C.EV_POLL_OUT_MAX, ts)

	if n < 0 then Errno:error("kevent") end
	C.gettimeofday(self.tv, nil)

	self.ev_in_pos = 0
	return self.ev_out, n
end


function Poller:abstime(rel)
	return rel + ((self.tv.tv_sec * 1000LL) + (self.tv.tv_usec / 1000LL))
end


function Poller:reltime(abs)
	return abs - ((self.tv.tv_sec * 1000LL) + (self.tv.tv_usec / 1000LL))
end


return ffi.metatype("struct LeveePoller", Poller)
