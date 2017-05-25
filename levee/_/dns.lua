local ffi = require("ffi")
local C = ffi.C


local errors = require("levee.errors")


local error_type = ffi.typeof("int[1]")


local _ = {}


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
	if not qclass then qclass = C.DNS_C_IN end
	local err = C.dns_res_submit(resolver, qname, qtype, qclass)
	if err ~= 0 then return errors.get(err) end

	return nil
end


return _
