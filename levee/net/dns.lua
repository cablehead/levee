local ffi = require("ffi")
local C = ffi.C

local levee = require("levee")
local _ = levee._

local errors = require("levee.errors")


--
-- Question

-- A Question is the input to a Resolver's query

local Question_mt = {}
Question_mt.__index = Question_mt


function Question_mt:__tostring()
	s = ("name=%s, type=%s, len=%s")
	s = s:format(self.name, self.type, self.len)
	return s
end


local function Question(qname, qtype)
	if not qtype then qtype = "A" end

	return setmetatable({
		name = qname,
		type = qtype,
		len = qname:len()}, Record_mt)
end


--
-- Record

-- A Record is the output of a Resolver's query

local Record_mt = {}
Record_mt.__index = Record_mt


function Record_mt:__tostring()
	s = ("name=%s, type=%s, record=%s, ttl=%s, section=%s")
	s = s:format(self.name, self.type, self.record, self.ttl, self.section)
	return s
end


function Record_mt:__lt(b)
	local a = self.record:gsub("%.+", "")
	a = tonumber(a)
	b = b.record:gsub("%.+", "")
	b = tonumber(b)
	return a <= b and not (b <= a)
end


local function Record(rname, rtype, record, ttl, section)
	return setmetatable({
		name = rname,
		type = rtype,
		record = record,
		ttl = ttl,
		section = section}, Record_mt)
end


local function parse_record(rr, packet)
	local rec = ffi.new("union dns_any")
	local size = ffi.sizeof("union dns_any")
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


local function parse(packet)
	local rr = ffi.new("struct dns_rr")
	local rri = ffi.new("struct dns_rr_i [1]")
	local recs = {}

	local rri = C.dns_rr_i_init(rri, packet);

	-- TODO handle packet with no results
	while true do
		local err, count = _.dns_rr_grep(rr, rri, packet)
		if err then return err end

		if count == 0 then return nil, recs end

		-- TODO support other sections
		local s = _.dns_section(rr)
		if s == "ANSWER" then
			local err, n = parse_name(rr, packet)
			if err then return err end

			local err, r = parse_record(rr, packet)
			if err then return err end

			r = Record(n, _.dns_type(rr), r, rr.ttl, s)
			table.insert(recs, r)
		end
	end

	return nil, recs
end


--
-- Resolver

-- A Resolver sends a Question to DNS server(s) and returns a table of Records

local Resolver_mt = {}
Resolver_mt.__index = Resolver_mt


function Resolver_mt:__poll(resv)
	if self.closed then return errors.CLOSED end

	-- TODO guard for failed queries/bad nameservers
	repeat
		local err, cont = _.dns_res_check(resv)
		if err then
			if not err.is_system_EAGAIN then return err end
			err = self.r_ev:recv(1000)
			if err then return err end
		end
	until not cont

	return nil
end


function Resolver_mt:__open(conf)
	local resv = self.__resolver
	if resv then return nil, resv end

	local err
	err, resv = _.dns_res_open(self.no, conf.resconf, conf.hosts, conf.hints)
	if err then return err end

	self.__resolver = resv
	return nil, resv
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

	local hosts
	if self.hosts then
		err, hosts = _.dns_hosts_loadpath(self.hosts)
		if err then return err end
	else
		err, hosts = _.dns_hosts_local()
		if err then return err end
	end

	local err, hints = _.dns_hints_local(resconf)
	if err then return err end

	if self.nsport or self.nsaddr then
		local sin_port, sin_addr
		if self.nsport then sin_port = C.htons(self.nsport) end
		if self.nsaddr then
			sin_addr = ffi.new("struct in_addr")
			C.inet_aton(ffi.cast("char*", self.nsaddr), sin_addr)
		end
		local head = hints.head
		while head ~= ffi.NULL do
			for i=0,head.count do
				local ss = ffi.cast("struct sockaddr_in*", head.addrs[i].ss)
				if ss.sin_addr.s_addr ~= 0 then
					if sin_addr then ss.sin_addr = sin_addr end
					if sin_port then ss.sin_port = sin_port end
				end
			end
			head = head.next
		end
	end

	conf = {resconf=resconf, hosts=hosts, hints=hints}
	self.__config = conf
	return nil, conf
end


function Resolver_mt:query(qname, qtype)
	if self.closed then return errors.CLOSED end

	local q = Question(qname, qtype)

	local err, conf = self:__load()
	if err then return err end

	local err, resv = self:__open(conf)
	if err then return err end

	err = _.dns_res_submit(resv, q.name, q.type)
	if err then return err end

	err = self:__poll(resv)
	if err then return err end

	local err, packet = _.dns_res_fetch(resv)
	if err then return err end

	return parse(packet)
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


local function Resolver(hub, no, port, addr, resconf, hosts)
	local self = setmetatable({}, Resolver_mt)
	self.hub = hub
	self.no = no
	self.r_ev = self.hub:register(no, true)
	self.nsport = port
	self.nsaddr = addr
	self.resconf = resconf
	self.hosts = hosts
	return self
end


local DNS_mt = {}
DNS_mt.__index = DNS_mt


function DNS_mt:resolver(port, addr, resconf, hosts)
	local err, no = _.socket(C.AF_INET, C.SOCK_DGRAM)
	if err then return err end
	_.fcntl_nonblock(no)
	return nil, Resolver(self.hub, no, port, addr, resconf, hosts)
end


return function(hub)
	return setmetatable({hub = hub}, DNS_mt)
end
