local ffi = require('ffi')


return {
	test_parser_request = function()
		local parser = require("levee.p.http").parser

		local request = "" ..
			"GET /some/path HTTP/1.1\r\n" ..
			"H1: one\r\n" ..
			"H2: two\r\n" ..
			"Content-Length: 13\r\n" ..
			"\r\n" ..
			"Hello World!\n"

		local buf = ffi.cast("char*", request)
		local len = #request

		local p = parser.Request()
		p:init_request()

		local err, rc = p:next(buf, 5)
		assert.equal(rc, 0)

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"GET", "/some/path", 1})
		buf = buf + rc
		len = len - rc

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"H1", "one"})
		buf = buf + rc
		len = len - rc

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"H2", "two"})
		buf = buf + rc
		len = len - rc

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"Content-Length", "13"})
		buf = buf + rc
		len = len - rc

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), true)
		buf = buf + rc
		len = len - rc

		assert.equal(ffi.string(buf, len), "Hello World!\n")
	end,

	test_parser_response = function()
		local parser = require("levee.p.http").parser

		local response = "" ..
			"HTTP/1.1 200 OK\r\n" ..
			"Date: Sun, 18 Oct 2009 08:56:53 GMT\r\n" ..
			"Content-Length: 13\r\n" ..
			"\r\n" ..
			"Hello World!\n"

		local buf = ffi.cast("char*", response)
		local len = #response

		local p = parser.Response()
		p:init_response()

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {200, "OK", 1})
		buf = buf + rc
		len = len - rc

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"Date", "Sun, 18 Oct 2009 08:56:53 GMT"})
		buf = buf + rc
		len = len - rc

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"Content-Length", "13"})
		buf = buf + rc
		len = len - rc

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), true)
		buf = buf + rc
		len = len - rc

		assert.equal(ffi.string(buf, len), "Hello World!\n")
	end,

	test_parser_stream_next = function()
		local levee = require("levee")

		local request = "" ..
			"GET /some/path HTTP/1.1\r\n" ..
			"H1: one\r\n" ..
			"H2: two\r\n" ..
			"Content-Length: 13\r\n" ..
			"\r\n" ..
			"Hello World!\n"

		local h = levee.Hub()
		local r, w = h.io:pipe()
		local stream = r:stream()
		w:write(request)

		local p = levee.p.http.parser.Request()
		p:init_request()

		local err, value = p:stream_next(stream)
		assert.same(value, {"GET", "/some/path", 1})
		local err, value = p:stream_next(stream)
		assert.same(value, {"H1", "one"})
		local err, value = p:stream_next(stream)
		assert.same(value, {"H2", "two"})
		local err, value = p:stream_next(stream)
		assert.same(value, {"Content-Length", "13"})

		local err, value = p:stream_next(stream)
		assert.same(value, {false, false, 13ULL})
	end,

	test_large_value = function()
		local parser = require("levee.p.http").parser

		local request = "" ..
			"GET /some/path HTTP/1.1\r\n" ..
			"Name: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\r\n" ..
			"Content-Length: 13\r\n" ..
			"\r\n" ..
			"Hello World!\n"


		local buf = ffi.cast("char*", request)
		local len = #request

		local p = parser.Request()
		p:init_request()

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"GET", "/some/path", 1})
		buf = buf + rc
		len = len - rc

		local err, rc = p:next(buf, len)
		assert(err ~= nil)


		local buf = ffi.cast("char*", request)
		local len = #request

		local p = parser.Request()
		p:init_request({ max_value = 2048 })
		p:reset() -- limits should be retained across a reset

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"GET", "/some/path", 1})
		buf = buf + rc
		len = len - rc

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"Name", "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"})
		buf = buf + rc
		len = len - rc

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"Content-Length", "13"})
		buf = buf + rc
		len = len - rc

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), true)
		buf = buf + rc
		len = len - rc

		assert.equal(ffi.string(buf, len), "Hello World!\n")
	end,
}
