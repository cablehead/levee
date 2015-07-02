return {
	test_call = function()
		local h = require("levee").Hub()

		local function add(a, b)
			return a + b
		end

		local recver = h.thread:call(add, 3, 2)
		assert.equal(recver:recv(), 5)
	end,
}
