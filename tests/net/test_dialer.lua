local levee = require("levee")

local _ = levee._
local errors = levee.errors


__test_core = function(async)
	local h = levee.Hub()

	local err, serve = h.stream:listen()
	local err, addr = serve:addr()
	local port = addr:port()

	assert(h:in_use())

	local err, conn = h.dialer:dial(C.AF_INET, C.SOCK_STREAM, "127.0.0.1", port, nil, async)
	assert(not err)
	assert(conn.no > 0)
	local err, s = serve:recv()
	s:close()
	h:unregister(conn.no, true, true)
	h:continue()
	serve:close()

	local err, conn = h.dialer:dial(C.AF_INET, C.SOCK_STREAM, "localhost", port, nil, async)
	assert.equal(err, errors.system.ECONNREFUSED)
	assert(not conn)

	local err, conn = h.dialer:dial(C.AF_INET, C.SOCK_STREAM, "kdkd", port, nil, async)
	if async then
		assert.contains(err, {errors.dns.NXDOMAIN, errors.addr.ENODATA})
	else
		assert.equal(err, errors.addr.ENONAME)
	end

	-- timeout
	local err, conn = h.dialer:dial(C.AF_INET, C.SOCK_STREAM, "10.244.245.246", port, 20, async)
	assert.equal(err, errors.TIMEOUT)

	assert(not h:in_use())
end

return {
	test_core = function()
		__test_core()
	end,

	test_core_async = function()
		__test_core(true)
	end,
}
