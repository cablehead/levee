local levee = require("levee")
local _ = levee._


return {
	test_core = function()
		local h = levee.Hub()

		local buf = levee.d.Buffer(4096)

		local err, serve = h.stream:listen(nil, nil, 20)
		local err, addr = serve:addr()
		local err, c1 = h.stream:dial(addr:port())
		local err, s1 = serve:recv()

		assert.equal(s1:readinto(buf), levee.errors.TIMEOUT)

		c1:write("m1.1")
		s1:readinto(buf)
		assert.equal(buf:take(), "m1.1")

		local err, c2 = h.stream:dial(addr:port())
		local err, s2 = serve:recv()

		c2:write("m2.1")
		s2:readinto(buf)
		assert.equal(buf:take(), "m2.1")

		s1:write("m1.2")
		c1:readinto(buf)
		assert.equal(buf:take(), "m1.2")

		s2:write("m2.2")
		c2:readinto(buf)
		assert.equal(buf:take(), "m2.2")

		c1:close()
		s2:close()
		serve:close()

		s1:readinto(buf)
		c2:readinto(buf)
		assert(not h:in_use())
	end,

	test_conn_refused = function()
		local h = levee.Hub()

		-- bind to a random port to find a free one
		local err, serve = h.stream:listen()
		local err, addr = serve:addr()
		local port = addr:port()
		serve:close()
		assert(not h:in_use())

		-- attempt to connect once, to start connector thread
		local err, c = h.stream:dial(port)
		assert(err)

		local err, c = h.stream:dial(port)
		assert(err)
		assert(not h:in_use())
	end,

	test_conn_timeout = function()
		local h = levee.Hub()
		local err, c = h.stream:dial(8003, "127.0.23.67", nil, 20)
		assert.equal(err, levee.errors.TIMEOUT)
		assert(not h:in_use())
	end,
}
