require("levee.cdef")

local ffi = require("ffi")

local task = require("levee.task")
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
	int data_id;
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
	return Sender[key]
end

function Sender:__gc()
	if self.other ~= ffi.NULL then
		self.other.closed, self.other.other = true, nil
	end
end

function Sender:close()
	error("TODO: Sender:close")
end

function Sender:take()
	if self.coro == ffi.NULL then
		return
	end

	local co = self.coro
	self.coro = nil

	self.hub:resume(co, true)
	return refs.clear(self.data_id)
end

function Sender:send(data)
	if self.closed then
		return
	end

	if self.other:give(data) then
		return true
	end

	self.data_id = refs.new(data)
	return task.yield(self)
end

Sender.allocate = ffi.metatype("LeveeSender", Sender)


local Recver = {}
Recver.__index = function(self, key)
	if key == "hub" then
		return refs.get(self.hub_id)
	end
	return Recver[key]
end

function Recver:__gc()
	if self.other ~= ffi.NULL then
		self.other.closed, self.other.other = true, nil
	end
end

function Recver:close()
	error("TODO: Recver:close")
end

function Recver:__call()
	return self:recv()
end

function Recver:give(data)
	if self.coro == ffi.NULL then
		return
	end

	local co = self.coro
	self.coro = nil
	self.hub:resume(co, data)
	return true
end

function Recver:recv()
	if self.closed then
		return
	end

	local data = self.other:take()
	if data ~= nil then
		return data
	end

	return task.yield(self)
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
