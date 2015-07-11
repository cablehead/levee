local ffi = require('ffi')
local C = ffi.C

local sys = require("levee.sys")

return {
	test_getaddrinfo = function()
		local info = sys.socket.getaddrinfo("localhost")
		local buf = ffi.new("char [16]")
		local addr = ffi.cast("struct sockaddr_in *", info.ai_addr)
		C.inet_ntop(C.AF_INET, addr.sin_addr, buf, 16)
		assert.equal(ffi.string(buf), "127.0.0.1")
		C.freeaddrinfo(info)
	end,

	test_connect = function()
		local s = sys.socket.listen(C.AF_INET, C.SOCK_STREAM, 0, "127.0.0.1")
		local port = tonumber(sys.endpoint:sockname(s):port())
		local c = sys.socket.connect(port, "localhost")
		assert(c > 0)
		C.close(s)
		C.close(c)
		local c = sys.socket.connect(port, "localhost")
		assert(not c)
	end,
}
