local levee = require("levee")
local d = levee.d
local p = levee.p


return {
	test_core = function()
		local u1 = p.utf8.Utf8()
		local want = "hi: 😬👻"
		assert.equal(u1:encode(want), 30)   -- note 30 is the number bytes written
		local ffi = require("ffi")

		local u2 = p.utf8.Utf8()
		assert.equal(u2:decode(u1.buf, u1.len), 12)
		assert.equal(u2:peek(), want)
	end,
}
