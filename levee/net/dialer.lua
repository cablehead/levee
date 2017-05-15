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


ffi.cdef([[
struct LeveeDialerResponse {
	int err;
	struct addrinfo *info;
};
]])


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


local function sockaddr(family, node, service)
	local sa
	if family == C.AF_INET then
		sa = ffi.new("struct sockaddr_in[1]")
		sa[0].sin_family = family
		C.inet_aton(node, sa[0].sin_addr)
		sa[0].sin_port = C.htons(service)
	end

	if family == C.AF_INET6 then
		sa = ffi.new("struct sockaddr_in6[1]")
		sa[0].sin6_family = family
		sa[0].sin6_addr.__in6_u.__u6_addr8 = node
		sa[0].sin6_port = service
	end

	if family == C.AF_UNIX then
		sa = ffi.new("struct sockaddr_un[1]")
		sa[0].sun_family = family
		sa[0].sun_path = node
	end

	if not sa then return errors.system.EINVAL end
	return nil, ffi.cast("struct sockaddr*", sa), ffi.sizeof(sa[0])
end

local function connect(no, family, node, service, w_ev, timeout)
	local err, addr, size = sockaddr(family, node, service)
	if err then return err end

	local rc = C.connect(no, addr, size)
	if rc == 0 then return nil, no end

	local err = errors.get(ffi.errno())

	if err == errors.system.EISCONN then return nil, no end
	if err ~= errors.system.EINPROGRESS then return err end

	local err = w_ev:recv(timeout)
	if err then return err end

	return connect(no, family, node, service, w_ev)
end


local function connect_all(hub, family, socktype, nodes, service, timeout)
	local err
	for __, node in ipairs(nodes) do
		err = nil
		local no = C.socket(family, socktype, 0)
		if no < 0 then return errors.get(ffi.errno()) end

		_.fcntl_nonblock(no)
		local r_ev, w_ev = hub:register(no, true, true)

		err = connect(no, family, node, service, w_ev, timeout)

		if not err then
			return nil, {hub=hub, no=no, r_ev=r_ev, w_ev=w_ev}
		end
		hub:unregister(no, true, true)
	end

	return err, nil
end


function Dialer_mt:dial(family, socktype, node, service, timeout)
	node = node or "127.0.0.1"
	local nodes = {node}

	if family == C.AF_INET or family == C.AF_INET6 then
		local err, resv = self.hub.dns:resolver()
		if err then return err end

		local qtype = (family == C.AF_INET and "A" or "AAAA")
		local err, records = resv:query(node, qtype)
		if err then return err end
		if #records == 0 then
			resv:close()
			return errors.addr.ENONAME
		end

		nodes = {}
		for __, r in ipairs(records) do table.insert(nodes, r.record) end

		resv:close()
	end

	return connect_all(self.hub, family, socktype, nodes, service, timeout)
end


return function(hub)
	return setmetatable({hub = hub}, Dialer_mt)
end
