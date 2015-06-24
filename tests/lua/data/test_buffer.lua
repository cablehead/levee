local ffi = require('ffi')

local Buffer = require("levee.buffer")

return {
	test_core = function()
		function x(s, n)
			ret = ""
			for _ = 1, n do
				ret = ret .. s
			end
			return ret
		end

		local buf = Buffer(4096)
		assert.equal(#buf, 0)
		assert.equal(buf:peek_s(), "")

		local s = x(".", 1024)

		for i = 1, 10 do
			local size = i * 1024

			buf:ensure(size)
			ffi.copy(buf:tail(), s)
			buf:bump(#s)

			assert.equal(#buf, size)
			assert.equal(buf:peek_s(), x(".", size))
		end

		buf:trim(5120)
		assert.equal(#buf, 5120)
		assert.equal(buf:peek_s(), x(".", 5120))

		buf:trim()
		assert.equal(#buf, 0)
		assert.equal(buf:peek_s(), "")
	end,
}
