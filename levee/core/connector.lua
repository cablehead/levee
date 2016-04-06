--
-- Background thread to resolve connections
--

local Connector_mt = {}
Connector_mt.__index = Connector_mt


function Connector_mt:connect(host, port)
	self.child:send({host, port})
	return self.child:recv()
end


local function stream_thread(h)
	local _ = require("levee._")
	while true do
		local err, req = h.parent:recv()
		if err then break end
		local host, port = unpack(req)
		h.parent:pass(_.connect(host, port, C.SOCK_STREAM))
	end
end


local function dgram_thread(h)
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
		fn = dgram_thread
	else
		fn = stream_thread
	end
	return setmetatable({
		hub = hub,
		child = hub.thread:spawn(fn)
	}, Connector_mt)
end
