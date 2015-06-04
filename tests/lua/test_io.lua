return {
	test_io = function()
		local levee = require("levee")

		local h = levee.Hub()
		local r, w = h.io:pipe()

		w:write("foo")
		assert.equal(r:recv():take_s(), "foo")

		-- TODO: check clean up
	end,
}
