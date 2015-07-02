local message = require("levee.message")
local ffi = require('ffi')
local C = ffi.C



local Sender_mt = {}
Sender_mt.__index = Sender_mt


function Sender_mt:__tostring()
	local chan_id = C.levee_chan_event_id(self.chan)
	return string.format("levee.ChannelSender: listen=%d channel=%d",
		tonumber(self.recv_id), tonumber(chan_id))
end


function Sender_mt:send(val)
	-- TODO: check value type and call proper send
	return C.levee_chan_send_i64(self, val)
end


function Sender_mt:connect(chan)
	local recv_id = C.levee_chan_connect(self, chan.chan)
	if recv_id < 0 then
		-- TODO: expose connection error
		return nil
	end
	return Reciever(chan, recv_id)
end


function Sender_mt:close()
	C.levee_chan_sender_close()
end


ffi.metatype("LeveeChanSender", Sender_mt)



local Reciever_mt = {}
Reciever_mt.__index = Reciever_mt


function Reciever_mt:__tostring()
	return string.format("levee.ChannelReciever: id=%d", tonumber(self.id))
end


function Reciever_mt:pump(node)
	if node.type == C.LEVEE_CHAN_I64 then
		print(node.as.i64)
	end
end


-- TODO: find a better name
function Reciever_mt:create_sender()
	-- TODO: do we need to track senders
	local sender = C.levee_chan_sender_create(self.chan.chan, self.id)
	if sender == nil then
		-- TODO: some errors should not halt (e.g closed channel)
		Errno:error("levee_chan_sender_create")
	end
	return ffi.gc(sender, C.levee_chan_sender_unref)
end


local function Reciever(chan, id)
	return setmetatable({chan=chan, id=id}, Reciever_mt)
end



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

	local recv = Reciever(self, id)
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
			print("no reciever", recv_id)
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
