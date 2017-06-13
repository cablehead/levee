local ffi = require("ffi")
local C = ffi.C

local levee = require("levee")
local _ = levee._

local errors = require("levee.errors")



local function parse_record(rr, packet)
	local rec = ffi.new("union dns_any")
	local size = ffi.sizeof(rec)
	rec = C.dns_any_init(rec, size)
	local buf = ffi.new("char[?]", size)

	local err = C.dns_any_parse(rec, rr, packet)
	if err ~= 0 then return errors.get(err) end
	C.dns_any_print(buf, size, rec, rr.type)

	return nil, ffi.string(buf)
end


local function parse_name(rr, packet)
	local err, any = _.dns_d_expand(rr, packet)
	if err then return err end

	return nil, ffi.string(any.ns.host)
end


local function parse(packet, qtype)
	local rr = ffi.new("struct dns_rr")
	local rri = ffi.new("struct dns_rr_i [1]")
	local recs = {}

	local rri = C.dns_rr_i_init(rri, packet);

	while true do
		local err, count = _.dns_rr_grep(rr, rri, packet)
		if err then return err end

		if count == 0 then return nil, recs end

		local s = _.dns_section(rr)
		local t = _.dns_type(rr)
		-- TODO support other sections
		if s == "ANSWER" and t == qtype then
			local err, n = parse_name(rr, packet)
			if err then return err end

			local err, r = parse_record(rr, packet)
			if err then return err end

			r = {name=n, type=t, record=r, ttl=rr.ttl, section=s}
			table.insert(recs, r)
		end
	end

	return nil, recs
end


local function nameservers(hints)
	local addrs = {}
	local head = hints.head

	while head ~= ffi.NULL do
		for i=0,head.count do
			local ss = ffi.cast("struct sockaddr_in*", head.addrs[i].ss)
			if ss.sin_addr.s_addr ~= 0 then
				table.insert(addrs, ss)
			end
		end
		head = head.next
	end

	return addrs
end


--
-- Resolver

-- A Resolver sends a question to DNS server(s) and returns a table of records

local Resolver_mt = {}
Resolver_mt.__index = Resolver_mt


function Resolver_mt:__poll(so, packet, nameserver, timeout)
	if self.closed then return errors.CLOSED end

	if not timeout then timeout = 500 end

	local err, data
	while not data do
		err, data = _.dns_so_query(so, packet, nameserver)
		if err then
			if not err.is_system_EAGAIN then return err end
			err = self.r_ev:recv(timeout)
			if err then return err end
		end
	end

	return nil, data
end


function Resolver_mt:__load()
	local conf = self.__config
	if conf then return nil, conf end

	local err, resconf
	if self.resconf then
		err, resconf = _.dns_resconf_loadpath(self.resconf)
		if err then return err end
	else
		err, resconf = _.dns_resconf_local()
		if err then return err end
	end

	local err, hints = _.dns_hints_local(resconf)
	if err then return err end

	local ns = nameservers(hints)
	if self.nsport or self.nsaddr then
		local sin_port, sin_addr
		if self.nsport then sin_port = C.htons(self.nsport) end
		if self.nsaddr then
			sin_addr = ffi.new("struct in_addr")
			C.inet_aton(self.nsaddr, sin_addr)
		end
		for __,addr in ipairs(ns) do
			if sin_addr then addr.sin_addr = sin_addr end
			if sin_port then addr.sin_port = sin_port end
		end
	end

	conf = {resconf=resconf, hosts=hosts, hints=hints, nameservers=ns}
	self.__config = conf
	return nil, conf
end


function Resolver_mt:query(qname, qtype, timeout)
	if self.closed then return errors.CLOSED end

	if not qtype then qtype = "A" end

	-- don't resolve IP addresses
	if not _.inet_pton(C.AF_INET, qname) then return errors.addr.ENONAME end
	if not _.inet_pton(C.AF_INET6, qname) then return errors.addr.ENONAME end

	local err, conf = self:__load()
	if err then return err end

	local err, question = _.dns_p_make()
	if err then return err end
	-- use recursion if the DNS server allows it
	question.header.rd = 1

	err = _.dns_p_push(question, qname, qtype)
	if err then return err end

	for __, addr in ipairs(conf.nameservers) do
		err, so = _.dns_so_open(self.no, conf.resconf.iface)
		if err then return err end

		err, packet = self:__poll(so, question, addr, timeout)
		if err and err ~= errors.TIMEOUT then return err end
		if packet then return parse(packet, qtype) end
	end

	return err
end


function Resolver_mt:close()
	if self.closed then
		return errors.CLOSED
	end

	self.closed = true
	self.hub:unregister(self.no, true)
	self.hub:continue()
	return
end


local function Resolver(hub, no, port, addr, resconf)
	local self = setmetatable({}, Resolver_mt)
	self.hub = hub
	self.no = no
	self.r_ev = self.hub:register(no, true)
	self.nsport = port
	self.nsaddr = addr
	self.resconf = resconf
	return self
end


local DNS_mt = {}
DNS_mt.__index = DNS_mt


function DNS_mt:resolver(port, addr, resconf, hosts)
	local err, no = _.socket(C.AF_INET, C.SOCK_DGRAM)
	if err then return err end
	_.fcntl_nonblock(no)
	return nil, Resolver(self.hub, no, port, addr, resconf)
end


return function(hub)
	return setmetatable({hub = hub}, DNS_mt)
end
