return {
	test_core = function()
		local levee = require("levee")

		local h = levee.Hub()
		local iov = levee.iovec.Iovec(4)

		local serve = h.tcp:listen(8000)

		local c1 = h.tcp:connect(8000)
		local s1 = serve:recv()

		iov:write("m1.1")
		c1:send(iov)
		iov:reset()
		assert(s1:recv():take_s() == "m1.1")

		local c2 = h.tcp:connect(8000)
		local s2 = serve:recv()

		iov:write("m2.1")
		c2:send(iov)
		iov:reset()
		assert(s2:recv():take_s() == "m2.1")

		iov:write("m1.2")
		s1:send(iov)
		iov:reset()
		assert(c1:recv():take_s() == "m1.2")

		iov:write("m2.2")
		s2:send(iov)
		iov:reset()
		assert(c2:recv():take_s() == "m2.2")

		-- TODO: check clean up
		-- c1:close()
		-- c2:close()
		-- serve:close()
	end,
}
