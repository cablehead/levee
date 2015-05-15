require('levee.cdef')

local ffi = require('ffi')
local Errno = require('levee.errno')

ffi.cdef[[
static const int EV_POLL_IN_MAX = 64;
static const int EV_POLL_OUT_MAX = 64;
struct LeveePoller {
	int fd;
	int ev_in_pos;
	uintptr_t id;
	struct kevent ev_in[EV_POLL_IN_MAX];
	struct kevent ev_out[EV_POLL_OUT_MAX];
};
]]

local C = ffi.C

local Poller = {}
Poller.__index = Poller


function Poller:__new()
	local self = ffi.new(self, C.kqueue(), 0, 0)
	if self.fd < 0 then Errno:error("kqueue") end
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
	if r then
		local ev = next_event(self)
		ev.ident = fd
		ev.filter = C.EVFILT_READ
		ev.flags = C.EV_DELETE
		ev.fflags = 0
		ev.data = 0
	end

	if w then
		local ev = next_event(self)
		ev.ident = fd
		ev.filter = C.EVFILT_WRITE
		ev.flags = C.EV_DELETE
		ev.fflags = 0
		ev.data = 0
	end

	-- TODO: shouldn't close until the en_in is flushed
	C.close(fd)
end


local POLLIN = 1
local POLLOUT = 2
local POLLERR = 3


function Poller:poll()
	--local n = C.kevent(self.fd, self.ev_in, self.ev_in_pos, self.ev_out,
	--	C.EV_POLL_OUT_MAX, nil)

	local n = C.kevent(self.fd, self.ev_in, self.ev_in_pos, self.ev_out, 1, nil)
	if n < 0 then Errno:error("kevent") end

	self.ev_in_pos = 0
	local e = self.ev_out[0]

	if e.filter == C.EVFILT_READ and e.data > 0 then
		return tonumber(e.ident), POLLIN, e.flags
	end

	-- it's possible to get an EOF and a WRITE in the same poll
	if bit.band(e.flags, bit.bor(C.EV_EOF, C.EV_ERROR)) > 0 then
		return tonumber(e.ident), POLLERR, e.flags
	end

	if e.filter == C.EVFILT_WRITE then
		return tonumber(e.ident), POLLOUT, e.flags
	end

end


return ffi.metatype("struct LeveePoller", Poller)
