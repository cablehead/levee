local levee = require("levee")

local _ = levee._
local errors = levee.errors


return {
	test_core = function()
		local h = levee.Hub()

		local err, serve = h.stream:listen()
		local err, addr = serve:addr()
		local port = addr:port()

		assert(h:in_use())

		local err, no = h.dialer:dial(C.AF_INET, C.SOCK_STREAM, "127.0.0.1", port)
		assert(not err)
		assert(no > 0)
		local err, s = serve:recv()
		s:close()
		C.close(no)
		serve:close()

		local err, no = h.dialer:dial(C.AF_INET, C.SOCK_STREAM, "localhost", port)
		assert.equal(err, errors.system.ECONNREFUSED)
		assert(not no)

		local err, no = h.dialer:dial(C.AF_INET, C.SOCK_STREAM, "kdkd", port)
		assert.equal(err, errors.addr.ENONAME)

		assert(not h:in_use())
	end,
}
