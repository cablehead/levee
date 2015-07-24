local levee = require("levee")


return {
	test_kv = function()
		print()
		print()

		local h = levee.Hub()
		local c = h.consul()

		assert.equal(c.kv:delete("foo"), true)
		assert.equal(c.kv:get("foo"), nil)

		assert.equal(c.kv:put("foo", "bar"), true)

		local index, data = c.kv:get("foo")
		assert.equal(data["Value"], "bar")

		assert.equal(c.kv:delete("foo"), true)
		assert.equal(c.kv:get("foo"), nil)
	end,
}
