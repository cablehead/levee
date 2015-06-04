return {
	test_io = function()
		local levee = require("levee")

		local h = levee.Hub()
		local r, w = h.io:pipe()

		w:write("foo")
		assert.equal(r:recv():take_s(), "foo")

		r:close()
		w:close()
		assert.same(h.registered, {})
	end,
}
