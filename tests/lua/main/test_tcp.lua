return {
	test_core = function()
		local levee = require("levee")

		local h = levee.Hub()

		local buf = levee.buffer(4096)
		local serve = h.tcp:listen(nil, nil, 20)

		local c1 = h.tcp:connect(serve:addr():port())
		local s1 = serve:recv()

		assert.equal(s1:readinto(buf), levee.TIMEOUT)

		c1:write("m1.1")
		s1:readinto(buf)
		assert(buf:take_s() == "m1.1")

		local c2 = h.tcp:connect(serve:addr():port())
		local s2 = serve:recv()

		c2:write("m2.1")
		s2:readinto(buf)
		assert(buf:take_s() == "m2.1")

		s1:write("m1.2")
		c1:readinto(buf)
		assert(buf:take_s() == "m1.2")

		s2:write("m2.2")
		c2:readinto(buf)
		assert(buf:take_s() == "m2.2")

		c1:close()
		s2:close()
		serve:close()

		s1:readinto(buf)
		c2:readinto(buf)
		assert.same(h.registered, {})
	end,
}
