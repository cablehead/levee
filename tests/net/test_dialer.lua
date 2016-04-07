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
	self.req.service_len = #service

	self.sender:send(self.req)
	self.sender:send(node)
	self.sender:send(service)

	self.recver:read(self.res)

	if self.res.err ~= 0 then return errors.get(self.res.err) end
	if self.res.eai ~= 0 then return errors.get_eai(self.res.eai) end

	return nil, self.res.no
end


function Dialer_mt:dial(family, socktype, node, service)
	local sender, recver = self.hub:pipe()
	self.q_sender:send({sender, family, socktype, node, service})
	return recver
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

	-- setup a loop to process requests in series
	self.q_sender, self.q_recver = hub:queue()
	hub:spawn(function()
		for req in self.q_recver do
			local sender, family, socktype, node, service = unpack(req)
			sender:pass(self:__dial(family, socktype, node, service))
			sender:close()
		end
	end)

	return nil, self
end


return {
	test_core = function()
		local h = levee.Hub()

		local err, dialer = Dialer(h)

		local err, s = h.stream:listen()
		local err, addr = s:addr()
		local port = tostring(addr:port())

		local err, no = dialer:dial(C.AF_INET, C.SOCK_STREAM, "127.0.0.1", port):recv()
		assert(not err)
		assert(no > 0)
		C.close(no)

		s:close()
		local err, no = dialer:dial(C.AF_INET, C.SOCK_STREAM, "localhost", port):recv()
		assert.equal(err, errors.system.ECONNREFUSED)
		assert(not no)

		local err, no = dialer:dial(C.AF_INET, C.SOCK_STREAM, "kdkd", port):recv()
		assert.equal(err, errors.addr.ENONAME)
	end,
}
