local ffi = require('ffi')

ffi.cdef[[
enum {
	EVFILT_READ     = -1,
	EVFILT_WRITE    = -2,
	EVFILT_AIO      = -3,
	EVFILT_VNODE    = -4,
	EVFILT_PROC     = -5,
	EVFILT_SIGNAL   = -6,
	EVFILT_TIMER    = -7,
	EVFILT_MACHPORT = -8,
	EVFILT_FS       = -9,
	EVFILT_USER     = -10,
	EVFILT_VM       = -12
};

enum {
	EV_ADD      = 0x0001,
	EV_DELETE   = 0x0002,
	EV_ENABLE   = 0x0004,
	EV_DISABLE  = 0x0008,
	EV_RECEIPT  = 0x0040,
	EV_ONESHOT  = 0x0010,
	EV_CLEAR    = 0x0020,
	EV_DISPATCH = 0x0080,
	EV_SYSFLAGS = 0xF000,
	EV_FLAG0    = 0x1000,
	EV_FLAG1    = 0x2000,
	EV_EOF      = 0x8000,
	EV_ERROR    = 0x4000,
	EV_POLL     = EV_FLAG0,
	EV_OOBAND   = EV_FLAG1
};

enum {
	NOTE_TRIGGER                      = 0x01000000,
	NOTE_FFNOP                        = 0x00000000,
	NOTE_FFAND                        = 0x40000000,
	NOTE_FFOR                         = 0x80000000,
	NOTE_FFCOPY                       = 0xc0000000,
	NOTE_FFCTRLMASK                   = 0xc0000000,
	NOTE_FFLAGSMASK                   = 0x00ffffff,
	NOTE_LOWAT                        = 0x00000001,
	NOTE_DELETE                       = 0x00000001,
	NOTE_WRITE                        = 0x00000002,
	NOTE_EXTEND                       = 0x00000004,
	NOTE_ATTRIB                       = 0x00000008,
	NOTE_LINK                         = 0x00000010,
	NOTE_RENAME                       = 0x00000020,
	NOTE_REVOKE                       = 0x00000040,
	NOTE_NONE                         = 0x00000080,
	NOTE_EXIT                         = 0x80000000,
	NOTE_FORK                         = 0x40000000,
	NOTE_EXEC                         = 0x20000000,
	NOTE_REAP                         = 0x10000000,
	NOTE_SIGNAL                       = 0x08000000,
	NOTE_EXITSTATUS                   = 0x04000000,
	NOTE_EXIT_DETAIL                  = 0x02000000,
	NOTE_PDATAMASK                    = 0x000fffff,
	NOTE_PCTRLMASK                    = 0xfff00000,
	NOTE_EXIT_REPARENTED              = 0x00080000,
	NOTE_EXIT_DETAIL_MASK             = 0x00070000,
	NOTE_EXIT_DECRYPTFAIL             = 0x00010000,
	NOTE_EXIT_MEMORY                  = 0x00020000,
	NOTE_EXIT_CSERROR                 = 0x00040000,
	NOTE_VM_PRESSURE                  = 0x80000000,
	NOTE_VM_PRESSURE_TERMINATE        = 0x40000000,
	NOTE_VM_PRESSURE_SUDDEN_TERMINATE = 0x20000000,
	NOTE_VM_ERROR                     = 0x10000000,
	NOTE_SECONDS                      = 0x00000001,
	NOTE_USECONDS                     = 0x00000002,
	NOTE_NSECONDS                     = 0x00000004,
	NOTE_ABSOLUTE                     = 0x00000008,
	NOTE_LEEWAY                       = 0x00000010,
	NOTE_CRITICAL                     = 0x00000020,
	NOTE_BACKGROUND                   = 0x00000040
};

struct kevent {
	uintptr_t ident;
	int16_t   filter;
	uint16_t  flags;
	uint32_t  fflags;
	intptr_t  data;
	uintptr_t udata;
};

int kqueue(void);
int kevent(int kq, const struct kevent *changelist, int nchanges,
		    struct kevent *eventlist, int nevents,
		    const struct timespec *timeout);
]]

local C = ffi.C
local kevent_list = ffi.typeof("struct kevent[?]")

local methods = {}
local mt = { __index = methods }

function methods:poll(fd, cb)
	if ev_in_pos == 64 then
		-- flush pending events if the list is full
		C.kevent(self.fd, self.ev_in, 64, nil, 0, nil)
		self.ev_in_pos = 0
	end

	local id = self.id

	local ev = self.ev_in[self.ev_in_pos]
	ev.ident = fd
	ev.filter = C.EVFILT_READ
	ev.flags = C.EV_ADD
	ev.fflags = 0
	ev.data = 0
	ev.udata = id

	self.callbacks[id] = cb
	self.id = self.id+1
	self.ev_in_pos = self.ev_in_pos + 1
end

function methods:run()
	while true do
		-- flush pending changes and poll for events
		local n = C.kevent(self.fd, self.ev_in, self.ev_in_pos, self.ev_out, 64, nil)
		self.ev_in_pos = 0
		for i=0,n-1 do
			local ev = self.ev_out[i]
			local cb = self.callbacks[tonumber(ev.udata)]
			cb(tonumber(ev.data))
		end
	end
end

function methods:register(fd)
	-- just registering one event at a time to get started
	--
	local ev = self.ev_in[0]
	ev.ident = fd
	ev.filter = C.EVFILT_READ
	ev.flags = bit.bor(C.EV_ADD, C.EV_CLEAR)
	ev.fflags = 0
	ev.data = 0
	ev.udata = self.id

	self.id = self.id + 1

	C.kevent(self.fd, self.ev_in, 1, self.ev_out, 0, nil)
	return self.id - 1
end


function methods:poll2()
	local n = C.kevent(self.fd, nil, 0, self.ev_out, 64, nil)
	print("poll got:", n)
	return tonumber(self.ev_out[0].udata)
end



local default = nil

return function()
	return setmetatable({
		id = 1,
		ev_in = kevent_list(64),
		ev_in_pos = 0,
		ev_out = kevent_list(64),
		callbacks = {},
		fd = ffi.C.kqueue()
	}, mt)
end
