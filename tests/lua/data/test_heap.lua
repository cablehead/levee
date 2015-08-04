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

	test_update_remove = function()
		local h = require('levee.heap')()

		local item1 = h:push(80, "1")
		local item2 = h:push(70, "2")
		local item3 = h:push(60, "3")
		local item4 = h:push(90, "4")

		item3:update(100)
		item2:remove()
		item1:update(95)

		local check = {}
		while #h > 0 do
			table.insert(check, {h:pop()})
		end
		assert.same(check, {{90ULL, "4"}, {95ULL, "1"}, {100ULL, "3"}})
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
	end,

	test_dense = function()
		local h = require('levee.heap')()

		h:push(80, "1")
		h:push(70, "2")
		h:push(60, "3")
		h:push(90, "4")
		assert.equal(#h.refs, 4)
		assert.equal(#h.avail, 0)

		h:pop()
		assert.equal(#h.refs, 4)
		assert.equal(#h.avail, 1)

		h:push(50, "5")
		assert.equal(#h.refs, 4)
		assert.equal(#h.avail, 0)
	end,
}
