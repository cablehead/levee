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

	test_if_else = function()
		local s = "1 {% if foo %} 2 {{ b }} {% else %} hrm {{c}} {% end %} 3"
		assert.equal(
			_.plate(s, {foo = true, b = "sub_b", c = "sub_c"}), "1  2 sub_b  3")
		assert.equal(
			_.plate(s, {foo = false, b = "sub_b", c = "sub_c"}), "1  hrm sub_c  3")
	end,

	test_nested = function()
		local s = "1 {% if foo %}2 {% if bar %}3 {{ a }}{% end %}{% end %} 5"
		assert.equal(
			_.plate(s, {foo = true, bar = true, a = 4}),
			"1 2 3 4 5")
		assert.equal(
			_.plate(s, {foo = true, bar = false, a = 4}),
			"1 2  5")
		assert.equal(
			_.plate(s, {foo = false, bar = true, a = 4}),
			"1  5")
		assert.equal(
			_.plate(s, {a = 4}),
			"1  5")
	end,
}
