local ffi = require('ffi')


local d = require("levee").d


return {
	test_core = function()
		local buf = d.Buffer(4096)
		assert.equal(#buf, 0)
		assert.equal(buf:peek(), "")

		local s = ("."):rep(1024)

		for i = 1, 10 do
			local size = i * 1024

			buf:ensure(size)
			ffi.copy(buf:tail(), s)
			buf:bump(#s)

			assert.equal(#buf, size)
			assert.equal(buf:peek(), ("."):rep(size))
		end

		assert.equal(buf:peek(10), ("."):rep(10))

		buf:trim(5120)
		assert.equal(#buf, 5120)
		assert.equal(buf:peek(), ("."):rep(5120))

		buf:trim()
		assert.equal(#buf, 0)
		assert.equal(buf:peek(), "")
	end,

	test_value = function()
		local buf = d.Buffer(4096)
		buf:write("foobar")
		assert.equal(ffi.string(buf:value()), "foobar")
		assert.equal(ffi.string(buf:value(8)), "foobar")
		assert.equal(ffi.string(buf:value(3)), "foo")
		assert.equal(ffi.string(buf:value(3, true)), "bar")
		assert.equal(ffi.string(buf:value(3, 1)), "b")
		assert.equal(ffi.string(buf:value(5, 2)), "r")
		assert.equal(ffi.string(buf:value(6, 1)), "")
	end,

	test_write = function()
		local b1 = d.Buffer()
		b1:write("foobar")
		local b2 = d.Buffer()
		b2:write(b1:value())
		assert.equal(ffi.string(b2:value()), "foobar")
	end,

	test_copy = function()
		local buf = d.Buffer(4096)
		local s = "012345678901234567890123456789"
		buf:push(s)
		local tgt = d.Buffer(4096)
		tgt:bump(buf:copy(tgt:tail()))
		assert.equal(tgt:peek(), s)
	end,

	test_save = function()
		local buf = d.Buffer(8192)
		buf:push("012345678901234567890123456789")

		buf:trim(10)
		local check = buf:available()

		buf:freeze(10)
		-- freezing will reclaim the trimmed offset
		assert.equal(check + 10, buf:available())
		assert.equal(buf:peek(), "0123456789")

		buf:trim(9)
		buf:push("oh hai")
		assert.equal(buf:peek(), "9oh hai")
		local check = buf:available()

		buf:thaw()
		-- thaw will reclaim the trimmed offset
		assert.equal(check + 9, buf:available())
		assert.equal(buf:peek(), "01234567899oh hai")
	end,

	test_butt = function()
		local buf = d.Buffer()
		buf:write("xxxfoobar123")
		buf:trim(3)

		local butt = buf:butt(3)

		assert.equal(#butt, 6)
		assert.equal(butt:peek(), "bar123")
		assert.equal(butt:peek(3), "bar")
		assert.equal(butt:peek(3, 1), "1")
		assert.equal(butt:peek(3, true), "123")

		butt:write("456")
		assert.equal(butt:peek(), "bar123456")

		butt:trim(3)
		assert.equal(buf:peek(), "foo123456")
		assert.equal(butt:peek(), "123456")

		butt:trim()
		assert.equal(buf:peek(), "foo")
		assert.equal(butt:peek(), "")
	end,
}
