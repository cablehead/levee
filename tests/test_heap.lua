return {
	test_peek = function()
		local Heap = require('levee.heap')
		local h = Heap()
		local val, prio

		prio, val = h:peek()
		assert.equals(nil, val)
		assert.equals(nil, prio)

		h:push(5, 100)
		prio, val = h:peek()
		assert.equals(5, prio)
		assert.equals(100, val)

		h:push(1, 200)
		prio, val = h:peek()
		assert.equals(1, prio)
		assert.equals(200, val)
	end,
	test_push_pop = function()
		local Heap = require('levee.heap')
		local h = Heap()
		math.randomseed(0)
		for i=1,10 do
			local pri = math.random(1000)
			h:push(pri, i)
		end
		assert.equals(10, #h)
		local last = -1
		for pri, i in h:popiter() do
			assert(pri >= last)
			last = pri
		end
	end,
	test_clear = function()
		local Heap = require('levee.heap')
		local ffi = require('ffi')
		local freed = false
		local val = ffi.gc(ffi.C.malloc(8), function(val)
			freed = true
			ffi.C.free(val)
		end)
		local h = Heap()
		h:push(1, val)
		h:push(2, val)
		val = nil
		collectgarbage("collect")
		assert(not freed)
		h:clear()
		collectgarbage("collect")
		assert(freed)
	end,
	test_final = function()
		local Heap = require('levee.heap')
		local ffi = require('ffi')
		local freed = false
		local val = ffi.gc(ffi.C.malloc(8), function(val)
			freed = true
			ffi.C.free(val)
		end)
		local h = Heap()
		h:push(1, val)
		h:push(2, val)
		val = nil
		collectgarbage("collect")
		assert(not freed)
		h = nil
		collectgarbage("collect")
		assert(freed)
	end
}
