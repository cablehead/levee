local ffi = require("ffi")
local C = ffi.C

local Buffer = require("levee.buffer")

local sockaddr_in = ffi.typeof("struct sockaddr_in")


return {
	test_core = function()
		local h = require("levee").Hub()

		local buf = Buffer(4096)

		local s = h.udp:listen(9000)

		local addr = sockaddr_in()
		addr.sin_family = C.AF_INET
		addr.sin_port = C.htons(9000)
		C.inet_aton("127.0.0.1", addr.sin_addr)

		local c = h.udp:create()

		c:sendto(addr, "123", 3)

		local n = s:recvfrom(addr, buf:tail())
		assert(n >= 0)
		buf:bump(n)
		assert.equal(buf:take_s(), "123")

		-- print("SRC PORT:", tonumber(C.ntohs(addr.sin_port)))

		s:sendto(addr, "321", 3)

		local n = c:recvfrom(addr, buf:tail())
		assert(n >= 0)
		buf:bump(n)
		assert.equal(buf:take_s(), "321")

	end,
}
