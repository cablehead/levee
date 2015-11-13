return {
	test_core = function()
		local levee = require("levee")

		local h = levee.Hub()

		local buf = levee.d.Buffer(4096)

		local err, serve = h.tcp:listen(nil, nil, 20)
		local err, addr = serve:addr()
		local err, c1 = h.tcp:connect(addr:port())
		local err, s1 = serve:recv()

		assert.equal(s1:readinto(buf), levee.errors.TIMEOUT)

		c1:write("m1.1")
		s1:readinto(buf)
		assert.equal(buf:take(), "m1.1")

		local err, c2 = h.tcp:connect(addr:port())
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
		assert.same(h.registered, {})
	end,
}
