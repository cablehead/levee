local _ = require("levee")._


return {
	test_core = function()
		local s = "1 {{a}} 2 {{ b }}3"
		assert.equal(_.plate(s, {a = "A", b = "B"}), "1 A 2 B3")
	end,
}
