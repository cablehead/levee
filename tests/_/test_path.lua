local _ = require("levee")._


return {
	test_dirname = function()
		assert.equal(_.dirname("/bin/foo"), "/bin")
	end,

	test_basename = function()
		assert.equal(_.basename("/bin/foo"), "foo")
	end,

	test_procname = function()
		local err, s = _.procname()
		assert(not err)
		assert.equal(_.basename(s), "levee")
	end,
}
