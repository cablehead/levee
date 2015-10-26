return {
	test_core = function()
		local errors = require("levee.errors")
		local want = errors.add(2001, "test", "BAD", "some bad thing")
		assert.equal(want.code, -2001)
		local got = errors.get(2001)
		assert.equal(want, got)
	end,
}
