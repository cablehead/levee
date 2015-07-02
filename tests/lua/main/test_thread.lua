return {
	test_call = function()
		local h = require("levee").Hub()

		local function add(a, b)
			return a + b
		end

		local recver = h.thread:call(add, 3, 2)
		assert.equal(recver:recv(), 5)
	end,

	test_spawn = function()
		local h = require("levee").Hub()

		local function f(h)
			assert(h.parent:recv() == 123)
			h.parent:send(321)
		end

		local child = h.thread:spawn(f)
		child:send(123)
		assert.equal(child:recv(), 321)
	end,
}
