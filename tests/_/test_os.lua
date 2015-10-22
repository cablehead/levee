local ffi = require('ffi')
local C = ffi.C

local _ = require("levee")._


if true then return {

	test_os = function()
		local err, r, w = _.pipe()
		assert(not err)
		assert.same({nil, 3}, {_.write(w, "foo")})
		assert.same({nil, "foo"}, {_.reads(r)})
	end,

} end

return {
	test_core = function()
		local no = C.open("foo121", bit.bor(C.O_RDONLY, C.O_NONBLOCK))
		assert(no < 0)

		local str = debug.getinfo(1, "S").source:sub(2)
		local no = C.open(str, bit.bor(C.O_RDONLY, C.O_NONBLOCK))

		local st = sys.os.fstat(no)
		assert(st.st_size > 0)
		assert(st:is_reg())
		assert(not st:is_dir())

		local st = sys.os.stat("foo121")
		assert.equal(st, nil)

		local st = sys.os.stat(str)
		assert(st.st_size > 0)
		assert(st:is_reg())
		assert(not st:is_dir())

		local st = sys.os.stat(dirname(str))
		assert(not st:is_reg())
		assert(st:is_dir())
	end,
}
