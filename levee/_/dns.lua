local ffi = require("ffi")
local C = ffi.C


local errors = require("levee.errors")


local error_type = ffi.typeof("int[1]")


local _ = {}

_.dns_strerror = function(err)
	if type(err) == "cdata" and ffi.typeof(err) == error_type then
		err = err[0]
	end

	if tonumber(err) > 0 then return errors.get(err) end

	if tonumber(err) < tonumber(C.DNS_ELAST) then
		if err == C.DNS_NOHINTS then
			return "Could not load hints"
		end
		if err == C.DNS_NORRI then
			return "Could not init rri"
		end
		if err == C.DNS_PRINT then
			return "Could not parse record to string"
		end
	end

	return ffi.string(C.dns_strerror(err))
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
	if err[0] ~= 0 then return _.dns_strerror(err),  nil end

	return nil, any
end

_.dns_rr_grep = function(rr, rri, packet, section)
	if not section then section = C.DNS_S_QD end

	local err = ffi.new(error_type, 0)

	local count = C.dns_rr_grep(rr, section, rri, packet, err)
	if err[0] ~= 0 then return _.dns_strerror(err), count end

	return nil, count
end

_.dns_rr_i_init = function(rri, packet)
	local rri = C.dns_rr_i_init(rri, data);
	if not rri then return _.dns_strerror(C.DNS_NORRI), nil end

	return nil, rri
end

_.dns_resconf_local = function()
	local err = ffi.new(error_type, 0)
	local resconf = C.dns_resconf_local(err)
	if err[0] ~= 0 then return _.dns_strerror(err), nil end

	return nil, resconf
end

_.dns_resconf_loadpath = function(path)
	local err = ffi.new("int[1]")
	local resconf = C.dns_resconf_open(err)
	if err[0] ~= 0 then return _.dns_strerror(err), nil end

	local err = C.dns_resconf_loadpath(resconf, path)
	if err ~= 0 and err ~= C.ENOENT then
		return _.dns_strerror(err), nil
	end

	local err = C.dns_nssconf_loadpath(resconf, "/etc/nsswitch.conf")
	if err ~= 0 and err ~= C.ENOENT then
		C.dns_resconf_close(resconf)
		return _.dns_strerror(err), nil
	end

	return nil, resconf
end

_.dns_hosts_local = function()
	local err = ffi.new(error_type, 0)
	local hosts = C.dns_hosts_local(err)
	if err[0] ~= 0 then return _.dns_strerror(err), nil end

	return nil, hosts
end

_.dns_hosts_loadpath = function(path)
	local err = ffi.new("int[1]")
	local hosts = C.dns_hosts_open(err)
	if err[0] ~= 0 then return _.dns_strerror(err), nil end

	local err = C.dns_hosts_loadpath(hosts, path)
	if err ~= 0 then return _.dns_strerror(err), nil
	end

	return nil, hosts
end

_.dns_hints_mortal = function(hints)
	local hints = C.dns_hints_mortal(hints)
	if not hints then return _.dns_strerror(C.DNS_NOHINTS), nil end

	return nil, hints
end

_.dns_hints_local = function(resconf)
	local err = ffi.new(error_type, 0)
	local hints = C.dns_hints_local(resconf, err)
	if err[0] ~= 0 then return _.dns_strerror(err), nil end

	return _.dns_hints_mortal(hints)
end

_.dns_hints_root = function(resconf)
	local err = ffi.new(error_type, 0)
	local hints = C.dns_hints_root(resconf, err)
	if err[0] ~= 0 then return _.dns_strerror(err), nil end

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
		 return _.dns_strerror(err), nil
	end
	ffi.gc(resolver, C.dns_res_close)

	return nil, resolver
end

_.dns_res_fetch = function(resolver)
	local err = ffi.new(error_type, 0)
	local packet = C.dns_res_fetch(resolver, err)
	if packet == ffi.NULL or err[0] ~= 0 then
		return _.dns_strerror(err), nil
	end
	ffi.gc(packet, C.free)

	return nil, packet
end

_.dns_res_check = function(resolver)
	local err = C.dns_res_check(resolver)
	if err ~= 0 then return _.dns_strerror(err), true end

	return nil, false
end

_.dns_res_submit = function(resolver, qname, qtype, qclass)
	if not qclass then qclass = C.DNS_C_IN end
	local err = C.dns_res_submit(resolver, qname, qtype, qclass)
	if err ~= 0 then return _.dns_strerror(err) end

	return nil
end


return _
