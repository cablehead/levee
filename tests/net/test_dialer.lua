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


function Dialer_mt:dial(family, socktype, node, service)
	self.req.family = family
	self.req.socktype = socktype
	self.req.node_len = #node
	self.req.service_len = #service

	self.sender:send(self.req)
	self.sender:send(node)
	self.sender:send(service)

	self.recver:read(self.res)

	if self.res.err ~= 0 then return errors.get(self.res.err) end
	if self.res.eai ~= 0 then return errors.get_eai(self.res.eai) end

	return nil, self.res.no
end


local function Dialer(hub)
	local self = setmetatable({}, Dialer_mt)

	self.state = C.levee_dialer_init()
	if self.state.rc ~= 0 then return errors.get(self.state.rc) end

	self.hub = hub
	self.r, self.w = _.pipe()

	self.req = Request()
	self.req.no = self.w

	self.res = ffi.new("struct LeveeDialerResponse")

	-- Note we leave sender as blocking
	self.sender = hub.io:w(self.state.io[1])
	_.fcntl_nonblock(self.r)
	self.recver = hub.io:r(self.r)

	return nil, self
end


return {
	test_core = function()
		print()
		print()

		local h = levee.Hub()

		local err, dialer = Dialer(h)

		print(dialer:dial(C.AF_INET, C.SOCK_STREAM, "localhost", "8000"))
		print(dialer:dial(C.AF_INET, C.SOCK_STREAM, "localhost", "8080"))
		print(dialer:dial(C.AF_INET, C.SOCK_STREAM, "kdkd", "8080"))
	end,
}
