return {
	test_map = function()
		local Map = require("levee.d.map")
		local Iovec = require("levee.d.iovec")

		local map = Map()

		assert.same(map["test"], nil)
		map:add("Test", "value 1")
		assert.same(map["test"], "value 1")
		map:add("TEST", "value 2")
		assert.same(map["test"], { "value 1", "value 2" })
		map["Test"] = { "stuff", "things" }
		assert.same(map["test"], { "stuff", "things" })
		map["Other"] = "value"

		local iov = Iovec()
		iov:write(map)

		assert.equal(tostring(map), iov:string())
		assert.equal(#iov, 41)
		assert.equal(iov.n, 12)
	end,
}
