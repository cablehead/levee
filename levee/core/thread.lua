local ffi = require("ffi")
local C = ffi.C


local message = require("levee.core.message")


--
-- Data
-- encapsulation for data passed on a channel

ffi.cdef[[
struct LeveeData {
	const void *val;
	size_t len;
}; ]]


local Data_mt = {}
Data_mt.__index = Data_mt


function Data_mt:__new(val, len)
	return ffi.new(self, val, len)
end


function Data_mt:__gc()
	C.free(ffi.cast("void *", self.val))
end


function Data_mt:__tostring()
	return string.format("levee.Data: val=%p, len=%u", self.val, tonumber(self.len))
end


function Data_mt:__len()
	return self.len
end


function Data_mt:value()
	return self.val, self.len
end


function Data_mt:string()
	return ffi.string(self.val, self.len)
end


local Data = ffi.metatype("struct LeveeData", Data_mt)


local ctype_ptr = ffi.typeof("struct LeveeData")
local ctype_dbl = ffi.typeof("double")
local ctype_u64 = ffi.typeof("uint64_t")
local ctype_i64 = ffi.typeof("int64_t")


--
-- Channel

local Recver_mt = {}
Recver_mt.__index = Recver_mt


function Recver_mt:__tostring()
	local chan_id = C.levee_chan_event_id(self.chan.chan)
	return string.format(
		"levee.ChannelRecver: chan=%d id=%d",
		tonumber(chan_id),
		tonumber(self.id))
end


function Recver_mt:pump(node)
	if node.type == C.LEVEE_CHAN_NIL then
		self.queue:send(nil)
	elseif node.type == C.LEVEE_CHAN_PTR then
		local data = Data(node.as.ptr.val, node.as.ptr.len)
		node.as.ptr.val = nil
		self.queue:send(data)
	elseif node.type == C.LEVEE_CHAN_OBJ then
		self.queue:send(ffi.gc(node.as.obj.obj, node.as.obj.free))
	elseif node.type == C.LEVEE_CHAN_DBL then
		self.queue:send(tonumber(node.as.dbl))
	elseif node.type == C.LEVEE_CHAN_I64 then
		self.queue:send(node.as.i64)
	elseif node.type == C.LEVEE_CHAN_U64 then
		self.queue:send(node.as.u64)
	elseif node.type == C.LEVEE_CHAN_BOOL then
		self.queue:send(node.as.b)
	elseif node.type == C.LEVEE_CHAN_SND then
		self.queue:send(C.levee_chan_sender_ref(node.as.sender))
	end
end


function Recver_mt:recv()
	return self.queue:recv()
end


function Recver_mt:__call()
	return self.queue:recv()
end


function Recver_mt:create_sender()
	-- TODO: do we need to track senders
	local sender = C.levee_chan_sender_create(self.chan.chan, self.id)
	if sender == nil then
		-- TODO: some errors should not halt (e.g closed channel)
		error("levee_chan_sender_create")
	end
	return ffi.gc(sender, C.levee_chan_sender_unref)
end


local function Recver(chan, id)
	return setmetatable({
		chan = chan,
		id = id,
		-- TODO:
		queue = message.Pair(chan.hub:queue()), }, Recver_mt)
end


local Sender_mt = {}
Sender_mt.__index = Sender_mt


function Sender_mt:__tostring()
	local chan_id = C.levee_chan_event_id(self.chan)
	return string.format(
		"levee.ChannelSender: chan=%d id=%d",
		tonumber(chan_id),
		tonumber(self.recv_id))
end


function Sender_mt:send(val)
	-- TODO: check value type and call proper send
	if val == nil then
		return C.levee_chan_send_nil(self)
	elseif type(val) == "number" or ffi.istype(ctype_dbl, val) then
		return C.levee_chan_send_dbl(self, val)
	elseif type(val) == "boolean" then
		return C.levee_chan_send_bool(self, val)
	elseif ffi.istype(ctype_ptr, val) then
		local rc = C.levee_chan_send_ptr(self, val.val, val.len)
		if rc >= 0 then
			val.val = nil
			val.len = 0
		end
		return rc
	elseif ffi.istype(ctype_i64, val) then
		return C.levee_chan_send_i64(self, val)
	elseif ffi.istype(ctype_u64, val) then
		return C.levee_chan_send_u64(self, val)
	end
end


function Sender_mt:connect(chan)
	local recv_id = C.levee_chan_connect(self, chan.chan)
	if recv_id < 0 then
		-- TODO: expose connection error
		return nil
	end
	recv_id = tonumber(recv_id)
	local recver = Recver(chan, recv_id)
	chan.listeners[recv_id] = recver
	return recver
end


function Sender_mt:close()
	C.levee_chan_sender_close()
end


ffi.metatype("LeveeChanSender", Sender_mt)


local Channel_mt = {}
Channel_mt.__index = Channel_mt


function Channel_mt:__tostring()
	return string.format("levee.Channel: %d", self:event_id())
end


function Channel_mt:event_id()
	return C.levee_chan_event_id(self.chan)
end


function Channel_mt:close()
	C.levee_chan_close(self.chan)
end


function Channel_mt:bind()
	local id = tonumber(C.levee_chan_next_recv_id(self.chan))
	if id < 0 then
		-- channel is closed
		return nil
	end

	local recv = Recver(self, id)
	self.listeners[id] = recv
	return recv
end


function Channel_mt:pump()
	local head = C.levee_chan_recv(self.chan)
	while head ~= nil do
		local recv_id = tonumber(head.recv_id)
		local recv = self.listeners[recv_id]
		if recv then
			recv:pump(head)
		else
			print("no recver", recv_id)
		end
		head = C.levee_chan_recv_next(head)
	end
end


local function Channel(hub)
	local chan = ffi.new('LeveeChan *[1]')
	if C.levee_chan_create(chan, hub.poller.fd) < 0 then
		error("levee_chan_create")
	end
	ffi.gc(chan, C.levee_chan_unref)
	return setmetatable({hub=hub, chan=chan, listeners={}}, Channel_mt)
end


--
-- State
-- a lua state

ffi.cdef[[
struct LeveeState {
	Levee *child;
};
]]

local State_mt = {}
State_mt.__index = State_mt


local access_error = "invalid access of background state"
local sender_type = ffi.typeof("LeveeChanSender *")


local function check(child, ok)
	if ok then
		return true
	end
	return false, ffi.string(C.levee_get_error(child))
end


function State_mt:__new()
	local state = ffi.new(self)
	state.child = C.levee_create()
	return state
end


function State_mt:__gc()
	if self.child then
		C.levee_destroy(self.child)
		self.child = nil
	end
end


function State_mt:__tostring()
	return string.format("levee.State: %p", self)
end


function State_mt:load_file(path)
	if self.child == nil then
		return false, access_error
	end
	return check(self.child, C.levee_load_file(self.child, path))
end


function State_mt:load_string(str, name)
	if self.child == nil then
		return false, access_error
	end
	return check(self.child, C.levee_load_string(self.child, str, #str, name))
end


function State_mt:load_function(fn)
	-- TODO: what should the name be?
	return self:load_string(string.dump(fn), "main")
end


function State_mt:push(val)
	if self.child == nil then
		return
	end
	if type(val) == "number" then
		C.levee_push_number(self.child, val)
	elseif type(val) == "string" then
		C.levee_push_string(self.child, val, #val)
	elseif type(val) == "boolean" then
		C.levee_push_bool(self.child, val)
	elseif type(val) == "cdata" and ffi.typeof(val) == sender_type then
		C.levee_push_sender(self.child, val)
	else
		C.levee_push_nil(self.child)
	end
end


function State_mt:pop(n)
	if self.child == nil then
		return
	end
	C.levee_pop(self.child, n or 1)
end


function State_mt:run(narg, bg)
	if self.child == nil then
		return false, access_error
	end
	local child = self.child
	if bg then
		self.child = nil
	end
	return check(child, C.levee_run(child, narg, not not bg))
end


local State = ffi.metatype("struct LeveeState", State_mt)


--
-- Thread

local Thread_mt = {}
Thread_mt.__index = Thread_mt


function Thread_mt:channel()
	if self.chan == nil then
		self.chan = Channel(self.hub)
	end
	return self.chan
end


function Thread_mt:call(f, ...)
	local state = State()

	-- bootstrap
	assert(state:load_function(
		function(sender, f, ...)
			local ok, got = pcall(loadstring(f), ...)

			if not ok then
				-- TODO: we should work an optional error message into Pipe close
				print("ERROR:", got)
			else
				-- TODO: close
				sender:send(got)
			end
		end))

	local recver = self:channel():bind()
	state:push(recver:create_sender())

	state:push(string.dump(f))

	local args = {...}
	for i = 1, #args do
		state:push(args[i])
	end
	state:run(2 + #args, true)

	return recver
end


function Thread_mt:spawn(f)
	local state = State()

	-- bootstrap
	assert(state:load_function(
		function(sender, f)
			local levee = require("levee")
			local h = levee.Hub()
			h.parent = levee.message.Pair(sender, sender:connect(h.thread:channel()))

			local ok, got = pcall(loadstring(f), h)

			if not ok then
				-- TODO: we should work an optional error message into Pipe close
				print("ERROR:", got)
			else
				-- TODO: close
			end
		end))

		local recver = self:channel():bind()
		state:push(recver:create_sender())

		state:push(string.dump(f))
		state:run(2, true)

		return message.Pair(recver:recv(), recver)
end


return function(hub)
	return setmetatable({hub = hub}, Thread_mt)
end
