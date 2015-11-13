return {
	test_nested = function()
		local p = require("levee.p")

		local want = {
			foo = "bar",
			arr = {3, -4, "foo", true, false, 3.7},
		}

		local err, buf = p.msgpack.encode(want)

		local err, got = p.msgpack.decoder():stream(buf)
		assert(not err)
		assert.same(want, got)
		assert.equal(#buf, 0)
	end,

	test_stream = function()
		local levee = require("levee")

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
}
