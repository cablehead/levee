return {
	test_push_pop = function()
		local Heap = require('levee.heap')
		local h = Heap()
		math.randomseed(0)
		for i=1,10 do
			local pri = math.random(1000)
			h:push(pri, pri)
		end
		assert.equals(10, #h)
		local last = -1
		for pri in h:popiter() do
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
