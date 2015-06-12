local ffi = require('ffi')
local C = ffi.C

return {
	test_stat = function()
		local no = ffi.C.open("foo121", bit.bor(C.O_RDONLY, C.O_NONBLOCK))
		assert(no < 0)

		local str = debug.getinfo(1, "S").source:sub(2)
		local no = ffi.C.open(str, bit.bor(C.O_RDONLY, C.O_NONBLOCK))

		local st = ffi.new("struct stat")
		local rc = C.fstat64(no, st)
		assert.equal(rc, 0)
		assert(st.st_size > 0)
	end,
}
