return {
	test_io_close_writer = function()
		local levee = require("levee")

		local h = levee.Hub()
		local r, w = h.io:pipe()

		w:write("foo")

		local buf = levee.buffer(4096)
		local n, err = r:read(buf:tail())
		buf:bump(n)
		assert.equal(buf:take_s(), "foo")

		w:close()

		local n, err = r:read(buf:tail())
		assert(n <= 0)
		assert(err > 0)

		local n, err = r:read(buf:tail())
		assert(n <= 0)
		assert(err > 0)

		assert.same(h.registered, {})
	end,

	test_io_last_read = function()
	end,
}
