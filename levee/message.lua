require("levee.cdef")

local ffi = require("ffi")

local task = require("levee.task")
local refs = require("levee.refs")


ffi.cdef[[
typedef struct LeveeSender LeveeSender;
typedef struct LeveeRecver LeveeRecver;
typedef struct LeveeSwitch LeveeSwitch;

/*
	Note: coro *must* be the first item in the struct
*/

struct LeveeSender {
	void *coro;
	LeveeRecver *other;
	int hub_id;
	int data_id;
	bool closed;
};

struct LeveeRecver {
	void *coro;
	void *other_;
	enum {
		LEVEE_SENDER,
		LEVEE_SWITCH,
	} other_t;

	int hub_id;
	bool closed;
};

struct LeveeSwitch {
	LeveeRecver *other;
	bool on;
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
		self.other.closed, self.other.other_, self.other.other_t = true, nil, nil
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
	local other = self:other()
	if other then
		other.closed, other.other = true, nil
	end
end

function Recver:close()
	error("TODO: Recver:close")
end

function Recver:__call()
	return self:recv()
end

function Recver:other()
	if self.other_t == C.LEVEE_SENDER then
		return ffi.cast("LeveeSender *", self.other_)
	elseif self.other_t == C.LEVEE_SWITCH then
		return ffi.cast("LeveeSwitch *", self.other_)
	end
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

	local data = self:other():take()
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


local Switch = {}
Switch.__index = Switch

function Switch:__gc()
	if self.other ~= ffi.NULL then
		self.other.closed, self.other.other_, self.other.other_t = true, nil, nil
	end
end

function Switch:close()
	error("TODO: Switch:close")
end

function Switch:take()
	if not self.on then
		return
	end
	return true
end

function Switch:send(on)
	if self.closed then
		return
	end

	if on then
		self.on = true
		self.other:give(true)
	else
		self.on = false
	end
end

Switch.allocate = ffi.metatype("LeveeSwitch", Switch)


return {
	Pipe = function(hub)
		local sender = Sender.allocate()
		local recver = Recver.allocate()
		sender.hub_id, sender.closed, sender.other = hub.id, false, recver
		recver.hub_id, recver.closed, recver.other_ = hub.id, false, sender
		recver.other_t = C.LEVEE_SENDER
		return Pair.new(sender, recver)
	end,

	Switch = function(hub)
		local sender = Switch.allocate()
		local recver = Recver.allocate()
		sender.closed, sender.other, sender.on = false, recver, false
		recver.hub_id, recver.closed, recver.other_ = hub.id, false, sender
		recver.other_t = C.LEVEE_SWITCH
		return Pair.new(sender, recver)
	end,
}
