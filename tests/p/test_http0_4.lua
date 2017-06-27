local ffi = require('ffi')
local meta = require("levee.meta")
local HTTP = require("levee.p.http.0_4")
local Buffer = require("levee.d.buffer")
local Status = require("levee.p.http.status")
local Parser = require("levee.p.http.parse")



local USER_AGENT = ("%s/%s"):format(meta.name, meta.version.string)


return {
	test_encode_url_error = function()
		local params = {"fe", "\222"}
		local buf = Buffer(4096)

		local err = HTTP.encode_request("GET", "/", params, nil, nil, buf)
		assert(err.is_utf8_ETOOSHORT)
	end,

	test_encode_request = function()
		local path = "/fa"
		-- use an array to maintain params order
		local params = {"fe", "fi 😬"}
		local headers = {fa="fe", fi="fo"}
		local buf = Buffer(4096)

		local err = HTTP.encode_request("GET", path, params, headers, nil, buf)
		assert(not err)


		local p = Parser()
		p:init_request()

		buf = buf:value()
		local err, rc = p:next(buf, 5)
		assert.equal(rc, 0)

		local len = 129
		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"GET", "/fa?1=fe&2=fi+%F0%9F%98%AC", 1})
		buf = buf + rc
		len = len - rc

		local headers = {}
		for i=1,4 do
			local err, rc = p:next(buf, len)
			assert(rc > 0)
			assert.equal(p:is_done(), false)
			local k,v = p:value(buf)
			headers[k] = v
			buf = buf + rc
			len = len - rc
		end

		local want = {
			["User-Agent"]=USER_AGENT,
			Accept="*/*",
			fa="fe",
			fi="fo",
		}
		assert.same(headers, want)

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), true)
	end,

	test_encode_request_post = function()
		local path = "/fa"
		-- use an array to maintain params order
		local params = {"fe", "fi 😬"}
		local headers = {fa="fe", fi="fo"}
		local data = "fum\n"
		local buf = Buffer(4096)

		local err = HTTP.encode_request("POST", path, params, headers, data, buf)
		assert(not err)

		local p = Parser()
		p:init_request()

		buf = buf:value()
		local err, rc = p:next(buf, 5)
		assert.equal(rc, 0)

		local len = 130
		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"POST", "/fa?1=fe&2=fi+%F0%9F%98%AC", 1})
		buf = buf + rc
		len = len - rc

		local headers = {}
		for i=1,5 do
			local err, rc = p:next(buf, len)
			assert(rc > 0)
			assert.equal(p:is_done(), false)
			local k,v = p:value(buf)
			headers[k] = v
			buf = buf + rc
			len = len - rc
		end

		local want = {
			["User-Agent"]=USER_AGENT,
			["Content-Length"]="4",
			Accept="*/*",
			fa="fe",
			fi="fo",
		}
		assert.same(headers, want)

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), true)
		buf = buf + rc
		len = len - rc

		assert.equal(ffi.string(buf, len), "fum\n")
	end,

	test_encode_response = function()
		local headers = {fa="fe", fi="fo", Date="Sun, 18 Oct 2009 08:56:53 GMT"}
		local data = "fum\n"
		local buf = Buffer(4096)

		local err = HTTP.encode_response(Status(200), headers, data, buf)
		assert(not err)

		local p = Parser()
		p:init_response()

		buf = buf:value()
		local err, rc = p:next(buf, 5)
		assert.equal(rc, 0)

		local len = 95
		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {200, "OK", 1})
		buf = buf + rc
		len = len - rc

		local headers = {}
		for i=1,4 do
			local err, rc = p:next(buf, len)
			assert(rc > 0)
			assert.equal(p:is_done(), false)
			local k,v = p:value(buf)
			headers[k] = v
			buf = buf + rc
			len = len - rc
		end

		local want = {
			["Date"]="Sun, 18 Oct 2009 08:56:53 GMT",
			["Content-Length"]="4",
			fa="fe",
			fi="fo",
		}
		assert.same(headers, want)

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), true)
		buf = buf + rc
		len = len - rc

		assert.equal(ffi.string(buf, len), "fum\n")
	end,

	test_encode_response_length_body = function()
		local headers = {fa="fe", fi="fo", Date="Sun, 18 Oct 2009 08:56:53 GMT"}
		local buf = Buffer(4096)

		local err = HTTP.encode_response(Status(200), headers, 6, buf)
		assert(not err)

		local p = Parser()
		p:init_response()

		buf = buf:value()
		local err, rc = p:next(buf, 5)
		assert.equal(rc, 0)

		local len = 91
		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {200, "OK", 1})
		buf = buf + rc
		len = len - rc

		local headers = {}
		for i=1,4 do
			local err, rc = p:next(buf, len)
			assert(rc > 0)
			assert.equal(p:is_done(), false)
			local k,v = p:value(buf)
			headers[k] = v
			buf = buf + rc
			len = len - rc
		end

		local want = {
			["Date"]="Sun, 18 Oct 2009 08:56:53 GMT",
			["Content-Length"]="6",
			fa="fe",
			fi="fo",
		}
		assert.same(headers, want)

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), true)
	end,
}
