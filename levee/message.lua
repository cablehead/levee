local ffi = require("ffi")


ffi.cdef[[
typedef struct End End;
typedef struct Sender Sender;
typedef struct Recver Recver;

typedef struct Middle Middle;

struct End {
	Middle *middle;
	int index;
	int ref;
};

struct Sender {
	struct End;
};

struct Recver {
	struct End;
};

struct Middle {
	Sender *sender;
	Recver *recver;
};


void *malloc(size_t);
void free (void *);
]]

local C = ffi.C

local SIZEOF_MIDDLE = ffi.sizeof("Middle")
local SIZEOF_END = ffi.sizeof("End")

local Middle = {}
Middle.__index = Middle

function Middle:release(self)
	print("Middle:release")
end

function Middle.allocate()
	return ffi.gc(ffi.cast("Middle *", C.malloc(SIZEOF_MIDDLE)), Middle.release)
end

function Middle:__tostring()
	return string.format("Middle: others=[0x%08x,0x%08x], ref=%d",
		tonumber(ffi.cast("uintptr_t", self.sender)),
		tonumber(ffi.cast("uintptr_t", self.recver)),
		self.ref)
end

ffi.metatype("Middle", Middle)

local Sender = {}
Sender.__index = Sender

function Sender:release()
	print("Sender:release")
	self.ref = self.ref - 1
	if self.ref > 0 then return end
	if not self.middle.recver then
		C.free(self.middle)
	else
		self.middle.sender = nil
	end
	C.free(self)
end

function Sender:other()
	return self.middle.recver
end

function Sender.allocate()
	return ffi.gc(ffi.cast("Sender *", C.malloc(SIZEOF_END)), Sender.release)
end

ffi.metatype("Sender", Sender)


local Recver = {}
Recver.__index = Recver

function Recver:release()
	print("Recver:release")
	self.ref = self.ref - 1
	if self.ref > 0 then return end
	if not self.middle.sender then
		C.free(self.middle)
	else
		self.middle.recver = nil
	end
	C.free(self)
end

function Recver:other()
	return self.middle.sender
end

function Recver.allocate()
	return ffi.gc(ffi.cast("Recver *", C.malloc(SIZEOF_END)), Recver.release)
end

ffi.metatype("Recver", Recver)


------


local Pipe = {}


function Pipe:new(hub)
	local T = {hub = hub, closed = false}
	setmetatable(T, self)
	self.__index = self
	return T
end


function Pipe:__call()
	return self:recv()
end


function Pipe:send(data)
	if self.closed then
		return
	end

	local ready

	if self.ready then
		ready = self.ready
		self.ready = nil
	else
		self.ready = coroutine.running()
		ready = coroutine.yield()
	end

	self.hub:resume(ready, data)
	return true
end


function Pipe:recv()
	if self.closed then
		return
	end

	if self.ready then
		local ready = self.ready
		self.ready = nil
		self.hub:resume(ready, coroutine.running())
	else
		self.ready = coroutine.running()
	end

	return coroutine.yield()
end


function Pipe:close()
	if self.ready then
		self:send(nil)
	end
	self.closed = true
end



return {
	Pipe = Pipe,
	Foo = function()
		 local middle = Middle.allocate()

		 local sender = Sender.allocate()
		 local recver = Recver.allocate()

		 sender.ref = 2
		 recver.ref = 2

		 sender.middle = middle
		 recver.middle = middle

		 sender.index = 10
		 recver.index = 20

		 middle.sender = sender
		 middle.recver = recver

		 return middle
	end,
	End = End}
