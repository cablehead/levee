local Argv = require('levee.argv')

return {
	test_basic = function()
		local function exit(idx, opt, msg)
			return -- ignore errors for this test
		end
		local argv = Argv({
			"value", "1.23", "a", "b", "--stuff", "after", "-xyz", "final"},
			exit)
		assert.same("value", argv:next())
		assert.same(1.23, argv:number())
		assert.same({"a", "b"}, argv:argn(2))
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

	test_argn = function()
		local argv, last_opt, last_idx
		local function exit(idx, opt, msg)
			last_idx = idx
			last_opt = opt
		end

		-- test adjacent option
		argv = Argv({"--items", "a", "b", "--other"}, exit)
		assert.same("items", argv:option())
		assert.same({"a","b"}, argv:argn(2))
		assert.same("other", argv:option())
		assert.is_nil(last_opt)
		assert.is_nil(last_idx)

		-- test extra values
		argv = Argv({"--items", "a", "b", "c", "--other"}, exit)
		assert.same("items", argv:option())
		assert.same({"a","b"}, argv:argn(2))
		assert.same("c", argv:next())
		assert.same("other", argv:option())
		assert.is_nil(last_opt)
		assert.is_nil(last_idx)

		-- test too short
		argv = Argv({"--items", "a", "b"}, exit)
		assert.same("items", argv:option())
		assert.is_nil(argv:argn(3))
		assert.same("items", last_opt)
		assert.same(2, last_idx)
		last_opt = nil
		last_idx = nil

		-- test too short with adjacent option
		argv = Argv({"--items", "a", "b", "--other"}, exit)
		assert.same("items", argv:option())
		assert.is_nil(argv:argn(3))
		assert.same("items", last_opt)
		assert.same(2, last_idx)
		last_opt = nil
		last_idx = nil
	end,

	test_bad_value = function()
		local argv, last_opt, last_idx
		local function exit(idx, opt, msg)
			last_idx = idx
			last_opt = opt
		end

		-- test non-number
		argv = Argv({"--num", "xx"}, exit)
		assert.same("num", argv:option())
		assert.is_nil(argv:number())
		assert.same("num", last_opt)
		assert.same(2, last_idx)
		last_opt = nil
		last_idx = nil

		-- test no value
		argv = Argv({"--num"}, exit)
		assert.same("num", argv:option())
		assert.is_nil(argv:number())
		assert.same("num", last_opt)
		assert.same(2, last_idx)
		last_opt = nil
		last_idx = nil
	end,
}
