local ffi = require("ffi")
local C = ffi.C

local HTTPParser = require("levee.parser.http")

return {
	test_request = function()
		local request = "" ..
			"GET /some/path HTTP/1.1\r\n" ..
			"H1: one\r\n" ..
			"H2: two\r\n" ..
			"Content-Length: 13\r\n" ..
			"\r\n" ..
			"Hello World!\n"

		local buf = ffi.cast("char*", request)
		local len = #request

		local rc
		local p = HTTPParser()
		p:init_request()

		rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"GET", "/some/path", 1})
		buf = buf + rc
		len = len - rc

		rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"H1", "one"})
		buf = buf + rc
		len = len - rc

		rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"H2", "two"})
		buf = buf + rc
		len = len - rc

		rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"Content-Length", "13"})
		buf = buf + rc
		len = len - rc

		rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.equal(p:value(buf), false)
		buf = buf + rc
		len = len - rc

		rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), true)
		assert.equal(p:value(buf), "Hello World!\n")
		buf = buf + rc
		len = len - rc

		assert.equal(len, 0)
	end,

	test_response = function()
		local response = "" ..
			"HTTP/1.1 200 OK\r\n" ..
			"Date: Sun, 18 Oct 2009 08:56:53 GMT\r\n" ..
			"Content-Length: 13\r\n" ..
			"\r\n" ..
			"Hello World!\n"

		local buf = ffi.cast("char*", response)
		local len = #response

		local rc
		local p = HTTPParser()
		p:init_response()

		rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {200, "OK", 1})
		buf = buf + rc
		len = len - rc

		rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"Date", "Sun, 18 Oct 2009 08:56:53 GMT"})
		buf = buf + rc
		len = len - rc

		rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"Content-Length", "13"})
		buf = buf + rc
		len = len - rc

		rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.equal(p:value(buf), false)
		buf = buf + rc
		len = len - rc

		rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), true)
		assert.equal(p:value(buf), "Hello World!\n")
		buf = buf + rc
		len = len - rc

		assert.equal(len, 0)
	end,
}
