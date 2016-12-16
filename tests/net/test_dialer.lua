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

		local err, conn = h.dialer:dial(C.AF_INET, C.SOCK_STREAM, "127.0.0.1", port, 20)
		assert(not err)
		assert(conn.no > 0)
		local err, s = serve:recv()
		s:close()
		h:unregister(conn.no, true, true)
		h:continue()
		serve:close()

		local err, conn = h.dialer:dial(C.AF_INET, C.SOCK_STREAM, "localhost", port, 20)
		assert.equal(err, errors.system.ECONNREFUSED)
		assert(not conn)

		local err, conn = h.dialer:dial(C.AF_INET, C.SOCK_STREAM, "kdkd", port, 20)
		assert.equal(err, errors.addr.ENONAME)

		-- timeout
		local err, conn = h.dialer:dial(C.AF_INET, C.SOCK_STREAM, "127.0.23.67", port, 20)
		assert.equal(err, errors.TIMEOUT)

		assert(not h:in_use())
	end,
}
