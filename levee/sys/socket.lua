local ffi = require("ffi")
local C = ffi.C


local sockaddr_in = ffi.typeof("struct sockaddr_in")


local function connect(port, host)
	local no = C.socket(C.PF_INET, C.SOCK_STREAM, 0)
	if no < 0 then return nil, ffi.errno() end

	local addr = sockaddr_in()
	addr.sin_family = C.AF_INET
	addr.sin_port = C.htons(port);
	C.inet_aton(host or "0.0.0.0", addr.sin_addr)

	local rc = C.connect(
		no, ffi.cast("struct sockaddr *", addr), ffi.sizeof(addr))
	if rc < 0 then return nil, ffi.errno() end

	return no
end


local function listen(domain, typ, port, host, backlog)
	local no = C.socket(domain, typ, 0)
	if no < 0 then return nil, ffi.errno() end

	local on = ffi.new("int32_t[1]", 1)
	local rc = C.setsockopt(no, C.SOL_SOCKET, C.SO_REUSEADDR, on, ffi.sizeof(on))
	if rc < 0 then return nil, ffi.errno() end

	local addr = sockaddr_in()
	addr.sin_family = domain
	addr.sin_port = C.htons(port or 0);
	C.inet_aton(host or "127.0.0.1", addr.sin_addr)
	rc = C.bind(no, ffi.cast("struct sockaddr *", addr), ffi.sizeof(addr))
	if rc < 0 then return nil, ffi.errno() end

	if typ == C.SOCK_STREAM then
		rc = C.listen(no, backlog or 256)
		if rc < 0 then return nil, ffi.errno() end
	end

	return no
end


local function accept(no)
	local addr = sockaddr_in()
	local addr_len = ffi.new("socklen_t[1]")
	local accepted = C.accept(no, ffi.cast("struct sockaddr *", addr), addr_len)
	if accepted < 0 then
		return nil, ffi.errno()
	end
	return accepted
end

return {
	connect = connect,
	listen = listen,
	accept = accept,
}
