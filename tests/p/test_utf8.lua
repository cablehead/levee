local levee = require("levee")
local d = levee.d
local p = levee.p


return {
	test_core = function()
		local u1 = p.utf8.Utf8()
		local s = "hi: 😬👻"
		assert.same({u1:encode(s)}, {nil, 30LL})
		local u2 = p.utf8.Utf8()
		assert.same({u2:decode(u1.buf, u1.len)}, {nil, 12LL})
		assert.equal(u2:peek(), s)
	end,

	test_fixed = function()
		local b1 = d.Buffer(200)
		local s = "hi: 😬👻"
		local u1 = p.utf8.Utf8.from_fixed(b1:tail(), 20)
		local err = u1:encode(s)
		assert(err)
		local u1 = p.utf8.Utf8.from_fixed(b1:tail(), 40)
		assert.same({u1:encode(s)}, {nil, 30LL})

		local b2 = d.Buffer(200)
		local u2 = p.utf8.Utf8.from_fixed(b2:tail(), 10)
		local err = u2:decode(u1.buf, u1.len)
		assert(err)
		local u2 = p.utf8.Utf8.from_fixed(b2:tail(), 20)
		assert.same({u2:decode(u1.buf, u1.len)}, {nil, 12LL})
		assert.equal(u2:peek(), s)
	end,

	test_charlen = function()
		assert.equal(p.utf8.charlen("H"), 1)
		assert.equal(p.utf8.charlen("👻"), 4)
	end,
}
