local ffi = require("ffi")
local C = ffi.C

local levee = require("levee")
local _ = levee._

local errors = require("levee.errors")


local __sections = {
	[C.DNS_S_QD]="QUESTION",
	[C.DNS_S_AN]="ANSWER",
	[C.DNS_S_NS]="AUTHORITY",
	[C.DNS_S_AR]="ADDITIONAL"
}

local __types = {
	A=C.DNS_T_A,
	AAAA=C.DNS_T_AAAA,
	MX=C.DNS_T_MX,
	NS=C.DNS_T_NS,
	CNAME=C.DNS_T_CNAME,
	SOA=C.DNS_T_SOA,
	SRV=C.DNS_T_SRV,
	SRV=C.DNS_T_SRV,
	OPT=C.DNS_T_OPT,
	PTR=C.DNS_T_PTR,
	TXT=C.DNS_T_TXT,
	SSHFP=C.DNS_T_SSHFP
}

local __ctypes = {
	[C.DNS_T_A]={
		parser=C.dns_a_parse,
		printer=C.dns_a_print,
		struct="struct dns_a",
		size=ffi.sizeof("struct dns_a"),
		type="A"
	},
	[C.DNS_T_AAAA]={
		parser=C.dns_aaaa_parse,
		printer=C.dns_aaaa_print,
		struct="struct dns_aaaa",
		size=ffi.sizeof("struct dns_aaaa"),
		type="AAAA"
	},
	[C.DNS_T_MX]={
		parser=C.dns_mx_parse,
		printer=C.dns_mx_print,
		struct="struct dns_mx",
		size=ffi.sizeof("struct dns_mx"),
		type="MX"
	},
	[C.DNS_T_NS]={
		parser=C.dns_ns_parse,
		printer=C.dns_ns_print,
		struct="struct dns_ns",
		size=ffi.sizeof("struct dns_ns"),
		type="NS"
	},
	[C.DNS_T_CNAME]={
		parser=C.dns_cname_parse,
		printer=C.dns_cname_print,
		struct="struct dns_cname",
		size=ffi.sizeof("struct dns_cname"),
		type="CNAME"
	},
	[C.DNS_T_SOA]={
		parser=C.dns_soa_parse,
		printer=C.dns_soa_print,
		struct="struct dns_soa",
		size=ffi.sizeof("struct dns_soa"),
		type="SOA"
	},
	[C.DNS_T_SRV]={
		parser=C.dns_srv_parse,
		printer=C.dns_srv_print,
		struct="struct dns_srv",
		size=ffi.sizeof("struct dns_srv"),
		type="SRV"
	},
	[C.DNS_T_OPT]={
		parser=C.dns_opt_parse,
		printer=C.dns_opt_print,
		struct="struct dns_opt",
		size=ffi.sizeof("struct dns_opt"),
		type="OPT"
	},
	[C.DNS_T_PTR]={
		parser=C.dns_ptr_parse,
		printer=C.dns_ptr_print,
		struct="struct dns_ptr",
		size=ffi.sizeof("struct dns_ptr"),
		type="PTR"
	},
	[C.DNS_T_TXT]={
		parser=C.dns_txt_parse,
		printer=C.dns_txt_print,
		struct="struct dns_txt",
		size=ffi.sizeof("struct dns_txt"),
		type="TXT"
	},
	[C.DNS_T_SSHFP]={
		parser=C.dns_sshfp_parse,
		printer=C.dns_sshfp_print,
		struct="struct dns_sshfp",
		size=ffi.sizeof("struct dns_sshfp"),
		type="SSHFP"
	},
}


--
-- Question

-- A Question is the input to a Resolver's query

local Question_mt = {}
Question_mt.__index = Question_mt


function Question_mt:__tostring()
	s = ("name=%s, type=%s, len=%s, recurse=%s")
	s = s:format(self.name, self.type, self.len, self.recurse)
	return s
end


local function Question(qname, qtype)
	if not qtype then qtype = "A" end
	qtype = __types[qtype]

	local recurse = false
	if qtype ~= C.DNS_T_A then
		recurse = true
	end

	return setmetatable({
		name = qname,
		type = qtype,
		len = qname:len(),
		recurse = recurse}, Record_mt)
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


--
local function parse_record(rr, packet)
	local ctype = __ctypes[tonumber(rr.type)]
	local rec = ffi.new(ctype.struct)
	-- TODO verify size * 4 works in every case
	local size = ctype.size * 4
	local buf = ffi.new("char[?]", size)

	local err = ctype.parser(rec, rr, packet)
	if err ~= 0 then return _.dns_strerror(err), nil end
	err = ctype.printer(buf, size, rec)
	if err == 0 then return _.dns_strerror(C.DNS_PRINT), nil end

	return nil, ffi.string(buf)
end


local function parse_name(rr, packet)
	local err, any = _.dns_d_expand(rr, packet)
	if err then return err, nil end

	return nil, ffi.string(any.ns.host)
end


local function parse(packet)
	local rr = ffi.new("struct dns_rr")
	local rri = ffi.new("struct dns_rr_i [1]")
	local recs = {}

	-- TODO handle packet with no results
	local err, rri = _.dns_rr_i_init(rri, packet);
	if err then return err, nil end

	while true do
		local err, count = _.dns_rr_grep(rr, rri, packet)
		if err then return err, nil end

		if count == 0 then return nil, recs end
		if rr.section ~= C.DNS_S_QD then
			local err, n = parse_name(rr, packet)
			if err then return err, nil end

			local err, r = parse_record(rr, packet)
			if err then return err, nil end

			local s = __sections[tonumber(rr.section)]
			local t = __ctypes[tonumber(rr.type)]
			r = Record(n, t.type, r, rr.ttl, s)
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


function Resolver_mt:__open(recurse, conf)
	local resv = self.__resolvers[recurse]
	if resv then return nil, resv end

	local err
	err, resv = _.dns_res_open(self.no, conf.resconf, conf.hosts, conf.hints)
	if err then return err, nil end

	self.__resolvers[recurse] = resv
	return nil, resv
end


function Resolver_mt:__config(recurse)
	local conf = self.__configs[recurse]
	if conf then return nil, conf end

	local err, resconf
	if self.__resconf then
		err, resconf = _.dns_resconf_loadpath(self.__resconf)
		if err then return err, nil end
	else
		err, resconf = _.dns_resconf_local()
		if err then return err, nil end
	end

	local hosts
	if self.__hosts then
		err, hosts = _.dns_hosts_loadpath(self.__hosts)
		if err then return err, nil end
	else
		err, hosts = _.dns_hosts_local()
		if err then return err, nil end
	end

	local err, hints = _.dns_hints_local(resconf)
	if err then return err, nil end

	if recurse then
		resconf.options.recurse = recurse
		err, hints = _.dns_hints_root(resconf)
		if err then return err, nil end
	end

	conf = {resconf=resconf, hosts=hosts, hints=hints}
	self.__configs[recurse]= conf
	return nil, conf
end


function Resolver_mt:query(qname, qtype)
	if self.closed then return errors.CLOSED end

	local q = Question(qname, qtype)

	local err, conf = self:__config(q.recurse)
	if err then return err, nil end

	local err, resv = self:__open(q.recurse, conf)
	if err then return err, nil end

	err = _.dns_res_submit(resv, q.name, q.type)
	if err then return err, nil end

	err = self:__poll(resv)
	if err then return err, nil end

	local err, packet = _.dns_res_fetch(resv)
	if err then return err, nil end

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


local function Resolver(hub, no, resconf, hosts)
	local self = setmetatable({}, Resolver_mt)
	self.hub = hub
	self.no = no
	self.r_ev = self.hub:register(no, true)
	self.__resconf = resconf
	self.__hosts = hosts
	self.__configs = {}
	self.__resolvers = {}
	return self
end


local DNS_mt = {}
DNS_mt.__index = DNS_mt


function DNS_mt:resolver(resconf, hosts)
	local err, no = _.socket(C.AF_INET, C.SOCK_DGRAM)
	if err then return err end
	_.fcntl_nonblock(no)
	return nil, Resolver(self.hub, no, resconf, hosts)
end


return function(hub)
	return setmetatable({hub = hub}, DNS_mt)
end
