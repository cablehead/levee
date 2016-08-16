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

		local rep1 = r:find("/f")
		assert(rep1:available())
		local n1 = rep1:reserve()
		assert.equal(rep1.node, n1)

		local rep2 = r:find("/f")
		assert(rep1:available())
		local n2 = rep2:reserve()
		assert.equal(n1, n2)

		local rep3 = r:find("/f")
		assert(not rep1:available())
		local n3 = rep3:reserve()
		assert(n1 ~= n3)

		n1:restore()
		n2:restore()
		n3:restore()

		local rep4 = r:find("/f")
		assert(rep1:available())
		local n4 = rep4:reserve()
		assert.equal(n1, n4)
	end,

	test_reserve_no_avail = function()
		local r = d.HashRing()

		r:put("test1", 3, 2)
		local replica = r:find("/some/path")

		local node1 = replica:reserve()
		assert(node1:key(), "test1")
		local node2 = replica:reserve()
		assert(node2:key(), "test1")
		local node3 = replica:reserve()
		assert.equal(node3, nil)
	end,

	test_find_no_node = function()
		local r = d.HashRing()

		-- test when initially empty
		local replica = r:find("/some/path")
		assert.equal(replica, nil)

		-- test after last node deleted
		r:put("test1", 3, 2)
		r:del("test1")
		local replica = r:find("/some/path")
		assert.equal(replica, nil)
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
		local r = d.HashRing()

		r:put("test1", 3, 2)
		r:del("test1")
		r:put("test2", 3, 2)

		local count = 0
		for n in r:iter() do count = count + 1 end
		assert.equal(count, 3)
	end,
}
