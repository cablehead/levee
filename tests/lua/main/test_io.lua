return {
	test_close_writer = function()
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

	test_last_read = function()
		local levee = require("levee")

		local h = levee.Hub()
		local r, w = h.io:pipe()

		w:write("foo")
		w:close()

		local buf = levee.buffer(4096)
		local n, err = r:read(buf:tail())
		buf:bump(n)
		assert.equal(buf:take_s(), "foo")

		local n, err = r:read(buf:tail())
		assert(n <= 0)
		assert(err > 0)

		assert.same(h.registered, {})
	end,

	test_close_reader = function()
		local levee = require("levee")

		local h = levee.Hub()
		local r, w = h.io:pipe()

		r:close()

		-- continue is required to flush the close
		h:continue()

		local n, err = w:write("foo")
		assert(n <= 0)
		assert(err > 0)

		local n, err = w:write("foo")
		assert(n <= 0)
		assert(err > 0)
	end,

	test_readinto = function()
		local levee = require("levee")

		local h = levee.Hub()
		local r, w = h.io:pipe()

		local buf = levee.buffer(4096)

		w:write("foo")

		local n, err = r:readinto(buf)
		assert.equal(buf:take_s(), "foo")

		w:close()

		local n, err = r:readinto(buf)
		assert(n <= 0)
		assert(err > 0)

		assert.same(h.registered, {})
	end,

	test_iov = function()
		local levee = require("levee")

		local h = levee.Hub()
		local r, w = h.io:pipe()

		local iov = w:iov()

		local want = {}
		for i = 1, 10000 do
			table.insert(want, tostring(i))
			iov:send(tostring(i))
		end
		want = table.concat(want)

		local buf = levee.buffer(4096)
		while #buf < #want do
			r:readinto(buf)
		end
		assert.equal(buf:take_s(), want)
	end,
}
