local Argv = require('levee.argv')

return {
	test_basic = function()
		local argv = Argv({
			"value", "1.23", "a", "b", "--stuff", "after", "-xyz", "final"})
		assert.same("value", argv:next())
		assert.same(1.23, argv:number())
		assert.same({"a", "b"}, argv:list())
		assert.same("stuff", argv:option())
		assert.is_nil(argv:option())
		assert.is_nil(argv:number())
		assert.same("after", argv:next())
		assert.same("x", argv:option())
		assert.same("y", argv:option())
		assert.same("z", argv:option())
		assert.is_nil(argv:option())
		assert.same("final", argv:next())
	end,
}
