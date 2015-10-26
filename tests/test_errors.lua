local errors = require("levee.errors")


return {
	test_core = function()
		local e = errors.add(2001, "test", "BAD", "some bad thing")
		assert.equal(e.code, -2001)
		local got = errors.get(2001)
		assert.equal(e, got)

		assert(e:is("test", "BAD"))
		assert(not e:is("test", "FOO"))

		assert(e.is_test_BAD)
		assert(not e.is_test_FOO)
	end,

	test_next = function()
		local e = errors.get(-1)
		assert.equal(e:next().code, -2)
	end,

	--[[
	test_iter = function()
		errors.add(2001, "test", "BAD", "some bad thing")
		for err in errors() do
			print(err)
		end
	end,
	]]--
}
