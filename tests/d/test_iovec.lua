local ffi = require("ffi")
local Iovec = require("levee").d.Iovec


return {
	test_core = function()
		local iov = Iovec()
		local cdata, valuen, tailn, oldtailn

		assert.equal(#iov, 0)

		cdata, valuen = iov:value()
		assert.equal(valuen, 0)

		iov:ensure(4)

		cdata, valuen = iov:value()
		assert.equal(valuen, 0)
		assert.equal(#iov, 0)

		cdata, tailn = iov:tail()
		assert(tailn >= 4)
		assert.equal(#iov, 0)
		oldtailn = tailn

		iov:write("test")

		cdata, valuen = iov:value()
		assert.equal(valuen, 1)
		assert.equal(#iov, 4)

		cdata, tailn = iov:tail()
		assert.equal(tailn, oldtailn-1)
	end,

	test_manual = function()
		local iov = Iovec()
		iov:ensure(4)

		assert.equal(#iov, 0)

		local i, n = iov:tail()
		i[0].iov_base = ffi.cast("char *", "test")
		i[0].iov_len = 4
		i[1].iov_base = ffi.cast("char *", "value")
		i[1].iov_len = 5
		i[2].iov_len = 999 -- overwrite to check bump logic

		iov:bump(2) -- have bump calculate the new length

		assert.equal(#iov, 9)

		local i, n = iov:tail()
		i[0].iov_base = ffi.cast("char *", "stuff")
		i[0].iov_len = 5
		i[1].iov_len = 999 -- overwrite to check bump logic

		iov:bump(1, 5) -- manually bump the length

		assert.equal(#iov, 14)

		local i, n = iov:value()
		assert.equal(n, 3)
		assert.equal(ffi.string(i[0].iov_base, i[0].iov_len), "test")
		assert.equal(ffi.string(i[1].iov_base, i[1].iov_len), "value")
		assert.equal(ffi.string(i[2].iov_base, i[2].iov_len), "stuff")
	end,

	test_writeinto = function()
		ffi.cdef[[
		struct Person {
			char *first, *last;
		};
		size_t strlen(const char *s);
		]]

		local Person_mt = {}
		Person_mt.__index = Person_mt

		local space = " "

		function Person_mt:writeinto_iovec(iov)
			iov:writeraw(self.first, ffi.C.strlen(self.first))
			iov:write(space)
			iov:writeraw(self.last, ffi.C.strlen(self.last))
		end

		local Person = ffi.metatype("struct Person", Person_mt)

		local andy = Person()
		andy.first = ffi.cast("char *", "Andy")
		andy.last = ffi.cast("char *", "Gayton")

		local iov = Iovec()
		iov:write(andy)

		assert.equal(#iov, 11)
	end,
}
