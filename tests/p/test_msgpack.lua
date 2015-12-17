local levee = require("levee")

return {
	test_nested = function()
		local want = {
			foo = "bar",
			arr = {3, -4, "foo", true, false, 3.7},
		}

		local err, buf = levee.p.msgpack.encode(want)
		local err, got = levee.p.msgpack.decoder():stream(buf)
		assert(not err)
		assert.same(want, got)
		assert.equal(#buf, 0)
	end,

	test_stream = function()

		local h = levee.Hub()

		local r, w = h.io:pipe()
		local s = r:stream()

		local want = "foo"
		local err, buf = levee.p.msgpack.encode(want)
		w:send(buf)

		local err, got = levee.p.msgpack.decoder():stream(s)
		assert(not err)
		assert.same(want, got)
	end,

	test_more = function()
		local want = {
			params = {
							h = "50",
							w = "100" },
			foo = {},
			uri = "/1/5376404c0d42e0472e0784aa:100/gA/:/i2.jpg",
			headers = {
							Accept = "*/*",
							["User-Agent"] = "levee/0.3.2-alpha",
							Host = "cgraphics.imgix.net" } }
		local err, buf = levee.p.msgpack.encode(want)
		local err, got = levee.p.msgpack.decoder():stream(buf)
		assert.same(got, want)
	end,
}
