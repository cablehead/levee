local ffi = require('ffi')

local d = require("levee").d


return {
	test_reserve_restore = function()
		local r = d.HashRing()
		-- 3 replicas, 2 availability
		r:put("test1", 3, 2)
		r:put("test2", 3, 2)
		r:put("test3", 3, 2)

		assert.equal(r:get("test1"):key(), "test1")
		assert.equal(r:get("test2"):key(), "test2")
		assert.equal(r:get("test3"):key(), "test3")

		local replica1 = r:find("/some/path")
		assert(replica1:available())
		local node1 = replica1:reserve()
		assert.equal(replica1.node, node1)

		local replica2 = r:find("/another/path")
		assert(replica1:available())
		local node2 = replica2:reserve()
		assert.equal(replica2.node, node2)

		local replica3 = r:find("/short")
		assert(not replica1:available())
		local node3 = replica3:reserve()
		assert.equal(replica3.node, r:get("test2"))
		assert.equal(node3, r:get("test3"))

		node1:restore()
		node2:restore()
		node3:restore()

		local replica3 = r:find("/short")
		assert(replica1:available())
		local node3 = replica3:reserve()
		assert.equal(replica3.node, node3)
	end,

	test_reserve_no_avail = function()
		local r = d.HashRing()

		r:put("test1", 3, 2)
		local replica = r:find("/some/path")
		local node1 = replica1:reserve()
		assert(node1:key(), "test1")

		local node2 = replica1:reserve()
		assert(node2:key(), "test1")
		local node3 = replica1:reserve()
		assert.equal(node3, nil)
	end,

	test_iter = function()
		local r = d.HashRing()
		r:put("test1", 3, 2)
		r:put("test2", 3, 2)
		r:put("test3", 3, 2)

		local matched = { test1 = 0, test2 = 0, test3 = 0 }
		for n in r:find("/stuff"):iter() do
			local k = n:key()
			matched[k] = matched[k] + 1
		end

		assert.same(matched, {test1=3, test2=3, test3=3})
	end,

	test_del = function()
		-- this might be an issue. after deleted one node there appears to be an
		-- additional replica for the remaining node
		do return "SKIP" end
		local r = d.HashRing()
		-- 3 replicas, 2 availability
		r:put("test1", 3, 2)
		r:del("test1")
		r:put("test2", 3, 2)
		for n in r:iter() do
			print(n, n:key())
		end
	end,
}
