return {
	test_core = function()
		local levee = require("levee")

		local h = levee.Hub()

		local buf = levee.buffer(4096)
		local serve = h.tcp:listen()

		local c1 = h.tcp:connect(serve:addr():port())
		local s1 = serve:recv()

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

		print()
		print()

		c1:close()
		s2:close()
		serve:close()

		print("1")
		s1:readinto(buf)
		print("2")
		c2:readinto(buf)
		print("3")
		assert.same(h.registered, {})
	end,
}
