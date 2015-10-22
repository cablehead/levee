



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
