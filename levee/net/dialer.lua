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


function Request_mt:__len()
	return ffi.sizeof(self)
end


local Request = ffi.metatype("struct LeveeDialerRequest", Request_mt)


--
-- Dialer

local Dialer_mt = {}
Dialer_mt.__index = Dialer_mt


function Dialer_mt:__dial(family, socktype, node, service)
	self.req.family = family
	self.req.socktype = socktype
	self.req.node_len = #node
	service = tostring(service)
	self.req.service_len = #service

	self.sender:send(self.req)
	self.sender:send(node)
	self.sender:send(service)

	self.recver:read(self.res)

	if self.res.err ~= 0 then return errors.get(self.res.err) end
	if self.res.eai ~= 0 then return errors.get_eai(self.res.eai) end

	return nil, self.res.no
end


function Dialer_mt:init()
	if not self.state then
		self.state = C.levee_dialer_init()
		if self.state.rc ~= 0 then return errors.get(self.state.rc) end

		self.r, self.w = _.pipe()

		self.req = Request()
		self.req.no = self.w

		self.res = ffi.new("struct LeveeDialerResponse")

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
	return recver
end


return function(hub)
	return setmetatable({hub = hub}, Dialer_mt)
end
