local levee = require("levee")
local _ = levee._


return {
	test_core = function()
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

	test_conn_refused = function()
		local h = levee.Hub()

		-- bind to a random port to find a free one
		local err, serve = h.tcp:listen()
		local err, addr = serve:addr()
		local port = addr:port()
		serve:close()
		assert.same(h.registered, {})

		for no = 3, 65535 do local err, st = _.fstat(no) end
		-- count the number of in use file descriptors
		local pre = 0
		for no = 3, 65535 do
			local err, st = _.fstat(no)
			if st then pre = pre + 1 end
		end

		local err, c = h.tcp:connect(port)
		assert(err)
		assert.same(h.registered, {})

		-- check the number of in use file descriptors is the same
		local post = 0
		for no = 3, 65535 do
			local err, st = _.fstat(no)
			if st then post = post + 1 end
		end
		assert.equal(pre, post)
	end,
}
