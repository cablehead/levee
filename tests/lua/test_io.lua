return {
	test_io = function()
		local levee = require("levee")

		local h = levee.Hub()
		local r, w = h.io:pipe()
		local iov = levee.iovec.Iovec(4)

		iov:write("foo")
		iov:write("bar")
		w:send(iov)
		assert.equal(r:recv():take_s(), "foobar")
		iov:reset()
	end,
}
