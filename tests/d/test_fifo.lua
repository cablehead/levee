local d = require("levee").d

return {
	test_push_pop = function()
		local f = d.fifo()
		assert.equals(0, #f)
		f:push(1)
		assert.equals(1, #f)
		f:push(2)
		assert.equals(2, #f)
		assert.equals(1, f:pop())
		assert.equals(1, #f)
		assert.equals(2, f:pop())
		assert.equals(0, #f)
	end,

	test_peek = function()
		local f = d.fifo()
		f:push(1)
		assert.equals(1, f:peek())
		f:push(2)
		assert.equals(1, f:peek())
		f:pop()
		assert.equals(2, f:peek())
	end,

	test_remove = function()
		local f = d.fifo()
		f:push(1)
		f:push(2)
		f:push(3)
		f:remove(2)
		assert.equals(1, #f)
		assert.equals(3, f:peek())
		f:remove(1)
		assert.equals(0, #f)
	end,

	test_iter = function()
		local f = d.fifo()
		f:push(1)
		f:push(2)

		local i = 1
		for v in f:iter() do
			assert.equals(i, v)
			i = i + 1
		end
		assert.equals(3, i)

		-- test iter leaves the fifo intact
		local i = 1
		for v in f:iter() do
			assert.equals(i, v)
			i = i + 1
		end
		assert.equals(3, i)
	end,

	test_popiter = function()
		local f = d.fifo()
		f:push(1)
		f:push(2)
		local i = 1
		for v in f:popiter() do
			assert.equals(i, v)
			i = i + 1
		end
		assert.equals(0, #f)
	end,

	test_popiter_break = function()
		local f = d.fifo()
		f:push(1)
		f:push(2)
		for v in f:popiter() do
			break
		end
		assert.equals(1, #f)
	end,

	test_peekiter = function()
		local f = d.fifo()
		f:push(1)
		f:push(2)
		local i = 1
		for v in f:peekiter() do
			assert.equals(i, v)
			i = i + 1
		end
		assert.equals(0, #f)
	end,

	test_peekiter_break = function()
		local f = d.fifo()
		f:push(1)
		f:push(2)
		for v in f:peekiter() do
			break
		end
		assert.equals(2, #f)
	end,
}
