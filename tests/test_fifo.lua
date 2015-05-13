return {
	test_push_pop = function()
		local FIFO = require('levee.fifo')
		local f = FIFO()
		assert(f:count() == 0)
		f:push(1)
		assert(f:count() == 1)
		f:push(2)
		assert(f:count() == 2)
		assert(f:pop() == 1)
		assert(f:count() == 1)
		assert(f:pop() == 2)
		assert(f:count() == 0)
	end,

	test_peek = function()
		local FIFO = require('levee.fifo')
		local f = FIFO()
		f:push(1)
		assert(f:peek() == 1)
		f:push(2)
		assert(f:peek() == 1)
		f:pop()
		assert(f:peek() == 2)
	end,

	test_iter = function()
		local FIFO = require('levee.fifo')
		local f = FIFO()
		f:push(1)
		f:push(2)
		local i = 1
		for v in f:iter() do
			assert(v == i)
			i = i + 1
		end
		assert(f:count() == 0)
	end,

	test_iter_break = function()
		local FIFO = require('levee.fifo')
		local f = FIFO()
		f:push(1)
		f:push(2)
		for v in f:iter() do
			break
		end
		assert(f:count() == 1)
	end,

	test_peekiter = function()
		local FIFO = require('levee.fifo')
		local f = FIFO()
		f:push(1)
		f:push(2)
		local i = 1
		for v in f:peekiter() do
			assert(v == i)
			i = i + 1
		end
		assert(f:count() == 0)
	end,

	test_peekiter_break = function()
		local FIFO = require('levee.fifo')
		local f = FIFO()
		f:push(1)
		f:push(2)
		for v in f:peekiter() do
			break
		end
		assert(f:count() == 2)
	end,
}
