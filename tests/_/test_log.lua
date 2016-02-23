local _ = require("levee")._


return {
	test_core = function()
		local log = _.log.Log("test_log")
		log:info("hi")
	end,
}
