local ffi = require('ffi')
local C = ffi.C
local Data = require('levee.data')

local message = require("levee.message")


local ctype_ptr = ffi.typeof("struct LeveeData")
local ctype_dbl = ffi.typeof("double")
local ctype_u64 = ffi.typeof("uint64_t")
local ctype_i64 = ffi.typeof("int64_t")


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
	elseif node.type == C.LEVEE_CHAN_DBL then
		self.queue:send(tonumber(node.as.dbl))
	elseif node.type == C.LEVEE_CHAN_I64 then
		self.queue:send(node.as.i64)
	elseif node.type == C.LEVEE_CHAN_U64 then
		self.queue:send(node.as.u64)
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


-- TODO: find a better name
function Recver_mt:create_sender()
	-- TODO: do we need to track senders
	local sender = C.levee_chan_sender_create(self.chan.chan, self.id)
	if sender == nil then
		-- TODO: some errors should not halt (e.g closed channel)
		Errno:error("levee_chan_sender_create")
	end
	return ffi.gc(sender, C.levee_chan_sender_unref)
end


local function Recver(chan, id)
	return setmetatable({chan=chan, id=id, queue=chan.hub:queue()}, Recver_mt)
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
	elseif ffi.istype(ctype_ptr, val) then
		local rc = C.levee_chan_send_dbl(self, val.val, val.len)
		if rc >= 0 then
			val.val = nil
			val.len = 0
		end
		return rc
	elseif ffi.istype(ctype_i64) then
		return C.levee_chan_send_i64(self, val)
	elseif ffi.istype(ctype_u64) then
		return C.levee_chan_send_i64(self, val)
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


-- TODO: what would be a better name?
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
		Errno:error("levee_chan_create")
	end
	ffi.gc(chan, C.levee_chan_unref)
	return setmetatable({hub=hub,chan=chan,listeners={}}, Channel_mt)
end


return Channel
