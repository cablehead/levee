require("levee.cdef")

local ffi = require("ffi")
local coro = require("coro")

local refs = require("levee.refs")


ffi.cdef[[
typedef struct LeveeSender LeveeSender;
typedef struct LeveeRecver LeveeRecver;

/*
	Note: coro *must* be the first item in the struct
*/
struct LeveeSender {
	void *coro; /* lua_State */
	LeveeRecver *other;
	int hub_id;
	bool closed;
};

struct LeveeRecver {
	void *coro; /* lua_State */
	LeveeSender *other;
	int hub_id;
	bool closed;
};
]]


local C = ffi.C


local Sender = {}
Sender.__index = function(self, key)
	if key == "hub" then
		return refs.get(self.hub_id)
	end
	if key == "ready" then
		return self.other ~= ffi.NULL and self.other.coro ~= ffi.NULL
	end
	return Sender[key]
end

function Sender:__gc()
	if self.other ~= ffi.NULL then
		self.other.closed, self.other.other = true, nil
	end
end

function Sender:close()
	if self.ready then
		self:send(nil)
	end
	self.closed = true
end

function Sender:send(data)
	if self.closed then
		return
	end

	local co

	if self.ready then
		co = self.other.coro
		self.other.coro = nil
	else
		co = coro.yield(self)
	end

	self.hub:resume(co, data)
	return true
end

Sender.allocate = ffi.metatype("LeveeSender", Sender)


local Recver = {}
Recver.__index = function(self, key)
	if key == "hub" then
		return refs.get(self.hub_id)
	end
	if key == "ready" then
		return self.other ~= ffi.NULL and self.other.coro ~= ffi.NULL
	end
	return Recver[key]
end

function Recver:__gc()
	if self.other ~= ffi.NULL then
		self.other.closed, self.other.other = true, nil
	end
end

function Recver:close()
	if self.ready then
		self:send(nil)
	end
	self.closed = true
end

function Recver:__call()
	return self:recv()
end

function Recver:recv()
	if self.closed then
		return
	end

	if self.ready then
		local co = self.other.coro
		self.other.coro = nil
		self.hub:resume(co, coroutine.running())
		return coroutine.yield()
	end

	return coro.yield(self)
end

Recver.allocate = ffi.metatype("LeveeRecver", Recver)


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


return {
	Pipe = function(hub)
		 local sender = Sender.allocate()
		 local recver = Recver.allocate()
		 sender.hub_id, sender.closed, sender.other = hub.id, false, recver
		 recver.hub_id, recver.closed, recver.other = hub.id, false, sender
		 return Pair.new(sender, recver)
	end,
}
