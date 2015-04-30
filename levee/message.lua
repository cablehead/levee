local ffi = require("ffi")


ffi.cdef[[
typedef struct Sender Sender;
typedef struct Recver Recver;


struct Sender {
	Recver *other;
	int index;
};

struct Recver {
	Sender *other;
	int index;
};
]]

local C = ffi.C

local Sender = {}
Sender.__index = Sender

function Sender:release()
	print("Sender:release")
	if self.other ~= ffi.NULL then
		self.other.other = nil
	end
	C.free(self)
end

function Sender.allocate()
	return ffi.gc(
		ffi.cast("Sender *", C.malloc(ffi.sizeof("Sender"))), Sender.release)
end

ffi.metatype("Sender", Sender)


local Recver = {}
Recver.__index = Recver

function Recver:release()
	print("Recver:release")
	if self.other ~= ffi.NULL then
		self.other.other = nil
	end
	C.free(self)
end

function Recver.allocate()
	return ffi.gc(
		ffi.cast("Recver *", C.malloc(ffi.sizeof("Recver"))), Recver.release)
end

ffi.metatype("Recver", Recver)


local Pair = {}

Pair.__index = Pair

Pair.__index = function(self, key)
	if key == "sender" then
		return self[1]
	end
	if key == "recver" then
		return self[2]
	end
	return Pair[key]
end


function Pair:recv()
	print("oh hai", self)
end


function Pair.new(sender, recver)
	local t = {sender,  recver}
	setmetatable(t, Pair)
	return t
end





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

		 local sender = Sender.allocate()
		 local recver = Recver.allocate()

		 sender.other = recver
		 recver.other = sender
		 sender.index = 10
		 recver.index = 20

		 return Pair.new(sender, recver)

	end,
	End = End}
