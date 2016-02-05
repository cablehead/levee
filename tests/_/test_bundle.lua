local _ = require("levee")._


return {
	test_core = function()
		local filename = debug.getinfo(1, 'S').source:sub(2)
		local path = _.path.dirname(filename)
		assert(_.bundle(path)()["/test_bundle.lua"])
	end,
}
