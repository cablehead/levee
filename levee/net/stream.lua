local _ = require("levee._")
local p = require("levee.p")


local Listener_mt = {}
Listener_mt.__index = Listener_mt


function Listener_mt:recv()
	return self.recver:recv()
end


function Listener_mt:__call()
	local err, value = self.recver:recv()
	if not err then return value end
end


function Listener_mt:loop()
	while true do
		local err, sender, ev = self.r_ev:recv()
		if ev < -1 then
			self:close()
			return
		end

		while true do
			local err, no = _.accept(self.no)
			-- TODO: only break on EAGAIN, should close on other errors
			if err then break end

			_.fcntl_nonblock(no)
			local conn = self.hub.io:rw(no, self.timeout)

			local err
			if self.tls then
				-- what to do on error??
				err, conn = self.tls:upgrade(conn)
				assert(not err)
				err = conn:handshake()
				assert(not err)
			end

			self.sender:send(conn)
		end
	end
end


function Listener_mt:addr()
	return _.getsockname(self.no)
end


function Listener_mt:port()
	local err, addr = self:addr()
	if not err then
		return addr:port()
	end
end


function Listener_mt:spawn_every(f)
	return self.hub:spawn_every(self, f)
end


Listener_mt.sockname = Listener_mt.addr


function Listener_mt:close()
	if self.closed then
		return
	end

	self.closed = true
	self.hub:unregister(self.no, true)
	self.sender:close()
	self.hub:continue()
	return true
end


--
-- TCP module interface
--


-- maintain backwards compatibility
local function Options(port, host, timeout, connect_timeout)
	if type(port) == "table" then
		return port
	end

	-- attempt to treat this as a uri
	if type(port) == "string" then
		local err, uri = p.uri(port)
		if not err and uri.host then
			local options = {
				host = uri.host,
				port = uri.port or uri.scheme,
				}
			if host then
				for k, v in pairs(host) do
					options[k] = v
				end
			end
			return options
		end
	end

	return {
		port = port,
		host = host,
		timeout = timeout,
		connect_timeout = connect_timeout, }
end


local TCP_mt = {}
TCP_mt.__index = TCP_mt


function TCP_mt:dial(port, host, timeout, connect_timeout)
	local options = Options(port, host, timeout, connect_timeout)

	if options.tls then
		local TLS = require("levee.net.tls")
		local err, config = TLS.Config(options.tls)
		if err then return err end
		options.config = config
	end

	local conn
	if options.unix then
		local err, no
		err, no = _.socket(C.AF_UNIX , C.SOCK_STREAM)
		if err then return err end
		err = _.connect(no, _.endpoint_unix(options.unix))
		if err then return err end
		conn = {hub=self.hub, no=no}
		conn.r_ev, conn.w_ev = self.hub:register(no, true, true)
	else
		local err
		err, conn = self.hub.dialer:dial(
			C.AF_INET,
			C.SOCK_STREAM,
			options.host,
			options.port,
			options.connect_timeout,
			options.async)
		if err then return err end
	end

	conn.timeout = options.timeout
	conn = setmetatable(conn, self.hub.io.RW_mt)

	local err
	if options.tls then
		err, conn = options.config:upgrade(conn, options.tls.server_name)
		if err then return err end
		err = conn:handshake()
		if err then return err end
	end

	return nil, conn
end


TCP_mt.connect = TCP_mt.dial


function TCP_mt:listen(port, host, timeout)
	local options = Options(port, host, timeout)

	local domain
	local endpoint

	if options.unix then
		domain = C.AF_UNIX
		endpoint = _.endpoint_unix(options.unix)
	else
		domain = C.AF_INET
		endpoint = _.endpoint_in(options.host, options.port)
	end

	local self = setmetatable({hub = self.hub}, Listener_mt)

	if options.tls then
		local TLS = require("levee.net.tls")

		local err, config = TLS.Config(options.tls)
		if err then return err end
		local err, ctx = config:server()
		if err then return err end

		self.tls = ctx
	end

	local err, no = _.socket(domain, C.SOCK_STREAM)
	if err then return err end

	local err = _.listen(no, endpoint)
	if err then return err end

	_.fcntl_nonblock(no)
	self.no = no
	self.timeout = options.timeout
	self.r_ev = self.hub:register(no, true)
	self.sender, self.recver = self.hub:pipe()

	self.hub:spawn(self.loop, self)
	return nil, self
end


return function(hub)
	return setmetatable({hub = hub}, TCP_mt)
end
