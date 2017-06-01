local ffi = require("ffi")
local C = ffi.C


local errors = require("levee.errors")


local error_type = ffi.typeof("int[1]")


local _ = {}


local ctoh = {
	[C.DNS_C_IN]="IN",
	[C.DNS_C_ANY]="ANY"
}

local stoh = {
	[C.DNS_S_QD]="QUESTION",
	[C.DNS_S_AN]="ANSWER",
	[C.DNS_S_NS]="AUTHORITY",
	[C.DNS_S_AR]="ADDITIONAL"
}

local ttoh = {
	[C.DNS_T_A]="A",
	[C.DNS_T_AAAA]="AAAA",
	[C.DNS_T_MX]="MX",
	[C.DNS_T_NS]="NS",
	[C.DNS_T_CNAME]="CNAME",
	[C.DNS_T_SOA]="SOA",
	[C.DNS_T_SRV]="SRV",
	[C.DNS_T_OPT]="OPT",
	[C.DNS_T_PTR]="PRT",
	[C.DNS_T_TXT]="TXT",
	[C.DNS_T_SSHFP]="SSHFP"
}

local htoc = {
	IN=C.DNS_C_IN,
	ANY=C.DNS_C_ANY
}

local htos = {
	QUESTION=C.DNS_S_QD,
	ANSWER=C.DNS_S_AN,
	AUTHORITY=C.DNS_S_NS,
	ADDITIONAL=C.DNS_S_AR
}

local htot = {
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

local errors_ = {
	ENOBUFS=C.DNS_ENOBUFS,
	EILLEGAL=C.DNS_EILLEGAL,
	EORDER=C.DNS_EORDER,
	ESECTION=C.DNS_ESECTION,
	EUNKNOWN=C.DNS_EUNKNOWN,
	EADDRESS=C.DNS_EADDRESS,
	ENOQUERY=C.DNS_ENOQUERY,
	ENOANSWER=C.DNS_ENOANSWER,
	EFETCHED=C.DNS_EFETCHED,
	ESERVICE=C.DNS_ESERVICE,
	ENONAME=C.DNS_ENONAME,
	EFAIL=C.DNS_EFAIL,
	ELAST=C.DNS_ELAST,
}

_.dns_strerror = function(code)
	-- dont' override standard EAI errors
	if code == C.DNS_ENONAME then return tostring(errors.addr.ENONAME) end
	if code == C.DNS_ESERVICE then return tostring(errors.addr.ESERVICE) end
	if code == C.DNS_EFAIL then return tostring(errors.addr.EFAIL) end

	return C.dns_strerror(code)
end

for name,code in pairs(errors_) do
	errors.add(code, "dns", name, ffi.string(_.dns_strerror(code)))
end

_.dns_section = function(rr)
	return stoh[tonumber(rr.section)]
end

_.dns_type = function(rr)
	return ttoh[tonumber(rr.type)]
end

_.dns_p_make = function(size)
	if not size then
		size = ffi.offsetof("struct dns_packet", "data") + 260
	end

	local err = ffi.new(error_type, 0)
	local packet = C.dns_p_make(size, err)
	if err[0] ~= 0 then return errors.get(err[0]),  nil end

	return nil, packet
end

_.dns_p_push = function(packet, name, type_, section, class, ttl, any)
	if not type_ then type_ = "A" end
	if not section then section = "QUESTION" end
	if not class then class = "IN" end
	if not ttl then ttl = 0 end
	if not any then any = ffi.cast("void*", 0) end

	local err = C.dns_p_push(
		packet,
		htos[section],
		ffi.cast("void*", name),
		name:len(),
		htot[type_],
		htoc[class],
		ttl,
		any
	)
	if err ~= 0 then return errors.get(err),  nil end

	return nil, packet
end

_.dns_d_expand = function(rr, packet)
	local any = ffi.new("union dns_any")
	local err = ffi.new(error_type, 0)

	C.dns_d_expand(
			any.ns.host,
			ffi.sizeof(any.ns.host),
			rr.dn.p,
			packet,
			err
	)
	if err[0] ~= 0 then return errors.get(err[0]),  nil end

	return nil, any
end

_.dns_rr_grep = function(rr, rri, packet, section)
	if not section then section = C.DNS_S_QD end

	local err = ffi.new(error_type, 0)

	local count = C.dns_rr_grep(rr, section, rri, packet, err)
	if err[0] ~= 0 then return errors.get(err[0]), count end

	return nil, count
end

_.dns_resconf_local = function()
	local err = ffi.new(error_type, 0)
	local resconf = C.dns_resconf_local(err)
	if err[0] ~= 0 then return errors.get(err[0]), nil end

	return nil, resconf
end

_.dns_resconf_loadpath = function(path)
	local err = ffi.new("int[1]")
	local resconf = C.dns_resconf_open(err)
	if err[0] ~= 0 then return errors.get(err[0]), nil end

	local err = C.dns_resconf_loadpath(resconf, path)
	if err ~= 0 then return errors.get(err) end

	local err = C.dns_nssconf_loadpath(resconf, "/etc/nsswitch.conf")
	if err ~= 0 then
		C.dns_resconf_close(resconf)
		return errors.get(err)
	end

	return nil, resconf
end

_.dns_hosts_local = function()
	local err = ffi.new(error_type, 0)
	local hosts = C.dns_hosts_local(err)
	if err[0] ~= 0 then return errors.get(err[0]) end

	return nil, hosts
end

_.dns_hosts_loadpath = function(path)
	local err = ffi.new("int[1]")
	local hosts = C.dns_hosts_open(err)
	if err[0] ~= 0 then return errors.get(err[0]) end

	local err = C.dns_hosts_loadpath(hosts, path)
	if err ~= 0 then return errors.get(err)
	end

	return nil, hosts
end

_.dns_hints_mortal = function(hints)
	local hints = C.dns_hints_mortal(hints)
	if not hints then return errors.addr.EBADHINTS end

	return nil, hints
end

_.dns_hints_local = function(resconf)
	local err = ffi.new(error_type, 0)
	local hints = C.dns_hints_local(resconf, err)
	if err[0] ~= 0 then return errors.get(err[0]) end

	return _.dns_hints_mortal(hints)
end

_.dns_hints_root = function(resconf)
	local err = ffi.new(error_type, 0)
	local hints = C.dns_hints_root(resconf, err)
	if err[0] ~= 0 then return errors.get(err[0]) end

	return _.dns_hints_mortal(hints)
end

_.dns_res_open = function(no, resconf, hosts, hints, cache, opts)
	local err = ffi.new(error_type, 0)
	local resolver = C.levee_dns_res_open(
		no,
		resconf,
		hosts,
		hints,
		cache,
		opts,
		err
	)
	if resolver == ffi.NULL or err[0] ~= 0 then
		return errors.get(err[0])
	end
	ffi.gc(resolver, C.dns_res_close)

	return nil, resolver
end

_.dns_res_fetch = function(resolver)
	local err = ffi.new(error_type, 0)
	local packet = C.dns_res_fetch(resolver, err)
	if packet == ffi.NULL or err[0] ~= 0 then
		return errors.get(err[0])
	end
	ffi.gc(packet, C.free)

	return nil, packet
end

_.dns_res_check = function(resolver)
	local err = C.dns_res_check(resolver)
	if err ~= 0 then return errors.get(err), true end

	return nil, false
end

_.dns_res_submit = function(resolver, qname, qtype, qclass)
	if not qclass then qclass = "IN" end
	qtype = htot[qtype]
	qclass = htoc[qclass]
	local err = C.dns_res_submit(resolver, qname, qtype, qclass)
	if err ~= 0 then return errors.get(err) end

	return nil
end

_.dns_so_query = function(so, packet, nameserver)
	local err = ffi.new(error_type, 0)
	local data = C.dns_so_query(
		so,
		packet,
		ffi.cast("struct sockaddr *", nameserver),
		err
	)
	if err[0] ~= 0 then return errors.get(err[0]) end
	if data == ffi.NULL then data = nil end

	return nil, data
end

_.dns_so_open = function(no, iface, ifacetype, opts)
	if not ifacetype then ifacetype = C.SOCK_DGRAM end

	local err = ffi.new(error_type, 0)
	local so = C.levee_dns_so_open(
		no,
		ffi.cast("struct sockaddr *", iface),
		ifacetype,
		opts,
		err
	)
	if so == ffi.NULL or err[0] ~= 0 then
		return errors.get(err[0])
	end
	ffi.gc(so, C.dns_so_close)

	return nil, so
end

return _
