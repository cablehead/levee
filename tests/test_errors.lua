local errors = require("levee.errors")


return {
	test_core = function()
		local e = errors.get(2001)
		assert.equal(type(e), "nil")

		local want = errors.add(2001, "test", "BAD", "some bad thing")
		assert.equal(want.code, -2001)

		local e = errors.add(2001, "test", "BAD", "some bad thing")
		assert.equal(type(e), "nil")

		local e = errors.get(2001)
		assert.equal(want, e)
		assert(e:is("test", "BAD"))
		assert(not e:is("test", "FOO"))
		assert(e.is_test_BAD)
		assert(not e.is_test_FOO)
	end,

	test_next = function()
		local e = errors.get(-1)
		assert.equal(e:next().code, -2)
	end,

	test_iter = function()
		local e
		for err in errors() do e = err end
		assert.equal(e.code, -10101)  -- levee.closed
	end,

	test_enum = function()
		assert(errors.system.EACCES.is_system_EACCES)
	end,
}
