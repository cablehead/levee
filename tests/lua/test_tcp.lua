return {
	test_core = function()
		local levee = require("levee")

		local h = levee.Hub()

		local serve = h.tcp:listen(8000)

		local c1 = h.tcp:connect(8000)
		local s1 = serve:recv()

		c1:write("m1.1")
		assert(s1:recv():take_s() == "m1.1")

		local c2 = h.tcp:connect(8000)
		local s2 = serve:recv()

		c2:write("m2.1")
		assert(s2:recv():take_s() == "m2.1")

		s1:write("m1.2")
		assert(c1:recv():take_s() == "m1.2")

		s2:write("m2.2")
		assert(c2:recv():take_s() == "m2.2")

		c1:close()
		c2:close()
		serve:close()
		h:sleep(1)
		assert.same(h.registered, {})
	end,
}
