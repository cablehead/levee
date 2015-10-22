


local function connect(port, host)
	local no = C.socket(C.PF_INET, C.SOCK_STREAM, 0)
	if no < 0 then return nil, ffi.errno() end

	local info, ptr = getaddrinfo(host, tostring(port))

	local err

	while ptr ~= nil do
		local rc = C.connect(no, ptr.ai_addr, ptr.ai_addrlen)
		if rc == 0 then
			return no
		else
			err = ffi.errno()
		end
		ptr = ptr.ai_next
	end

	C.freeaddrinfo(info)

	return nil, err
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
	getaddrinfo = getaddrinfo,
	connect = connect,
	listen = listen,
	accept = accept,
}
