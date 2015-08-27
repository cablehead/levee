local path = require("levee.path")
local os = require("levee.sys.os")


return {
	test_proc = function()
		assert.equal(os.basename(path.proc()), "levee")
	end,
}
