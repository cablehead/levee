local levee = require("levee")

local _ = levee._
local errors = levee.errors


return {
	test_core = function()
		local h = levee.Hub()

		local err, s = h.stream:listen()
		local err, addr = s:addr()
		local port = addr:port()

		local err, no = h.dialer:dial(C.AF_INET, C.SOCK_STREAM, "127.0.0.1", port)
		assert(not err)
		assert(no > 0)
		C.close(no)

		s:close()
		local err, no = h.dialer:dial(C.AF_INET, C.SOCK_STREAM, "localhost", port)
		assert.equal(err, errors.system.ECONNREFUSED)
		assert(not no)

		local err, no = h.dialer:dial(C.AF_INET, C.SOCK_STREAM, "kdkd", port)
		assert.equal(err, errors.addr.ENONAME)
	end,
}
