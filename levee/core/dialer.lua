--
-- Background thread to resolve connections
--

local Dialer_mt = {}
Dialer_mt.__index = Dialer_mt


function Dialer_mt:dial(host, port)
	self.child:send({host, port})
	return self.child:recv()
end


local function dial_stream(h)
	local _ = require("levee._")
	while true do
		local err, req = h.parent:recv()
		if err then break end
		local host, port = unpack(req)
		h.parent:pass(_.connect(host, port, C.SOCK_STREAM))
	end
end


local function dial_dgram(h)
	local _ = require("levee._")
	while true do
		local err, req = h.parent:recv()
		if err then break end
		local host, port = unpack(req)
		h.parent:pass(_.connect(host, port, C.SOCK_DGRAM))
	end
end


return function(hub, stype)
	local fn
	if stype == C.SOCK_DGRAM then
		fn = dial_dgram
	else
		fn = dial_stream
	end
	return setmetatable({
		hub = hub,
		child = hub.thread:spawn(fn)
	}, Dialer_mt)
end
