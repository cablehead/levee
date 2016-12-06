local levee = require("levee")
local _ = levee._
local d = levee.d

return {
	test_old = function()
		local h = levee.Hub()

		local err, s = h.dgram:listen(9000)
		local err, c = h.dgram:dial(9000)

		c:write("123")
		local buf = levee.d.Buffer(4096)
		s:readinto(buf)
		assert.equal(buf:take(), "123")
	end,

	test_core = function()
		local h = levee.Hub()

		local err, s1 = h.dgram:bind()
		local err, s2 = h.dgram:bind()

		local err, ep1 = s1:addr()
		local err, ep2 = s2:addr()

		local buf = d.Buffer(4096)

		-- send from s1 to s2
		local err, n = s1:sendto(ep2, "foo")
		assert.equal(n, 3)
		local err, who, n = s2:recvfrom(buf:tail())
		assert.equal(tostring(who), tostring(ep1))
		assert.equal(n, 3)

		-- reply from s2 to s1
		local err, n = s2:sendto(who, "foobar")
		assert.equal(n, 6)
		local err, who, n = s1:recvfrom(buf:tail())
		assert.equal(tostring(who), tostring(ep2))
		assert.equal(n, 6)

		-- send 0 bytes
		local err, n = s1:sendto(ep2, "")
		assert.equal(n, 0)
		local err, who, n = s2:recvfrom(buf:tail())
		assert.equal(tostring(who), tostring(ep1))
		assert.equal(n, 0)

		-- test recvfrom blocks until ready
		h:spawn(function() h:sleep(10); local err, n = s1:sendto(ep2, "foo") end)
		local err, who, n = s2:recvfrom(buf:tail())
		assert.equal(tostring(who), tostring(ep1))
		assert.equal(n, 3)

		s1:close()
		s2:close()
	end,
}
