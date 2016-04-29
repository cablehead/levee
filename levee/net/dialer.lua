local ffi = require("ffi")

local levee = require("levee")

local _ = levee._
local errors = levee.errors


--
-- Dialer Request

local Request_mt = {}
Request_mt.__index = Request_mt


function Request_mt:value()
	return ffi.cast("char*", self), ffi.sizeof(self)
end


function Request_mt:writeinto_iovec(iov)
	iov:writeraw(self:value())
end


function Request_mt:__len()
	return ffi.sizeof(self)
end


local Request = ffi.metatype("struct LeveeDialerRequest", Request_mt)


--
-- Message

local Message_mt = {}
Message_mt.__index = Message_mt


function Message_mt:writeinto_iovec(iov)
	iov:write(self[1])
	iov:write(self[2])
	iov:write(self[3])
end


local function Message(req, node, service)
	return setmetatable({ req, node, service }, Message_mt)
end


--
-- Dialer

local Dialer_mt = {}
Dialer_mt.__index = Dialer_mt


function Dialer_mt:__dial(family, socktype, node, service)
	node = node or "127.0.0.1"
	service = service and tostring(service) or "0"

	self.req.family = family
	self.req.socktype = socktype
	self.req.node_len = #node
	self.req.service_len = #service

	self.sender:send(Message(self.req, node, service))

	self.recver:read(self.res)

	local res = self.res[0]
	if res < 0 then return errors.get(res) end
	return nil, res
end


function Dialer_mt:init()
	if not self.state then
		self.state = C.levee_dialer_init()
		if self.state.rc ~= 0 then return errors.get(self.state.rc) end

		self.r, self.w = _.pipe()

		self.req = Request()
		self.req.no = self.w

		self.res = ffi.new("int[1]")

		-- Note we leave sender as blocking
		self.sender = self.hub.io:w(self.state.io[1])
		_.fcntl_nonblock(self.r)
		self.recver = self.hub.io:r(self.r)

		-- setup a loop to process requests in series
		self.q_sender, self.q_recver = self.hub:queue()
		self.hub:spawn(function()
			for req in self.q_recver do
				local sender, family, socktype, node, service = unpack(req)
				sender:pass(self:__dial(family, socktype, node, service))
				sender:close()
			end
		end)
	end
end


function Dialer_mt:dial(family, socktype, node, service)
	self:init()
	local sender, recver = self.hub:pipe()
	self.q_sender:send({sender, family, socktype, node, service})
	return recver:recv()
end


return function(hub)
	return setmetatable({hub = hub}, Dialer_mt)
end
