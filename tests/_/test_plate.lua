local _ = require("levee")._


return {
	test_sub = function()
		local s = "1 {{a}} 2 {{ b }}3"
		assert.equal(_.plate(s, {a = "A", b = "B"}), "1 A 2 B3")
	end,

	test_if = function()
		local s = "1 {% if foo %} 2 {{ b }}hrm {% end %} 3"
		assert.equal(
			_.plate(s, {foo = true, b = "noog"}), "1  2 nooghrm  3")
		assert.equal(
			_.plate(s, {b = "noog"}), "1  3")
	end,
}
