local ffi = require('ffi')

local levee = require("levee")
local meta = require("levee.meta")
local HTTP = require("levee.p.http.0_4")
local Buffer = require("levee.d.buffer")
local Map = require("levee.d.map")
local Status = require("levee.p.http.status")


local USER_AGENT = ("%s/%s"):format(meta.name, meta.version.string)


local function buffer_zero()
	local buf = Buffer(4096)
	-- TODO memset here until Buffer adopts it
	C.memset(buf.buf, 0, 4096)
	return buf
end


local function parse_headers(p, buf, len, count)
	local headers = {}
	for i=1,count do
		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		local key, value = p:value(buf)
		if headers[key] then
			if type(headers[key]) == "string" then
				headers[key] = {headers[key]}
			end
			table.insert(headers[key], value)
		else
			headers[key] = value
		end
		buf = buf + rc
		len = len - rc
	end

	return headers, buf, len
end


local function assert_response_chunk(buf)
		local p = HTTP.Parser()
		p:init_response()

		buf = buf:value()
		local len= 120
		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {200, "OK", 1})
		buf = buf + rc
		len = len - rc

		local headers, buf, len = parse_headers(p, buf, len, 3)

		local want = {
			["Date"]="Sun, 18 Oct 2009 08:56:53 GMT",
			["Transfer-Encoding"]="chunked",
			fe="fi",
		}
		assert.same(headers, want)

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		buf = buf + rc
		len = len - rc

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {true, 4LL})
		buf = buf + rc
		len = len - rc

		rc = p.as.body_chunk.length
		assert(ffi.string(buf, rc), "fafe")
		buf = buf + rc
		len = len - rc

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.same({p:value(buf)}, {true, 2LL})
		assert.equal(p:is_done(), false)
		buf = buf + rc
		len = len - rc

		rc = p.as.body_chunk.length
		assert(ffi.string(buf, rc), "fi")
		buf = buf + rc
		len = len - rc

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.same({p:value(buf)}, {true, 2LL})
		assert.equal(p:is_done(), false)
		buf = buf + rc
		len = len - rc

		rc = p.as.body_chunk.length
		assert(ffi.string(buf, rc), "fa")
		buf = buf + rc
		len = len - rc

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		buf = buf + rc
		len = len - rc

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), true)
end


return {
	test_encode_url_error = function()
		local params = {"fe", "\222"}
		local buf = buffer_zero()

		local err = HTTP.encode_request(buf, "GET", "/", params)
		assert(err.is_utf8_ETOOSHORT)
	end,

	test_encode_request = function()
		local path = "/fa"
		local params = {"fe", "fi 😬"}
		local headers = {fo={"fum", "fa", "fe"}, fi="fo"}
		local data = "fum\n"
		local buf = buffer_zero()

		local err = HTTP.encode_request(buf, "POST", path, params, headers, data)
		assert(not err)

		local p = HTTP.Parser()
		p:init_request()

		buf = buf:value()
		local len = 147
		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"POST", "/fa?1=fe&2=fi+%F0%9F%98%AC", 1})
		buf = buf + rc
		len = len - rc

		local headers, buf, len =  parse_headers(p, buf, len, 7)

		local want = {
			["User-Agent"]=USER_AGENT,
			["Content-Length"]="4",
			Accept="*/*",
			fo={"fum", "fa", "fe"},
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

	test_encode_request_map = function()
		local path = "/fa"
		local params = {"fe", "fi 😬"}
		local headers = Map()
		headers:add("fo", "fum")
		headers:add("fo", "fa")
		headers:add("fo", "fe")
		headers:add("fi", "fo")
		local buf = buffer_zero()

		local err = HTTP.encode_request(buf, "GET", path, params, headers)
		assert(not err)

		local p = HTTP.Parser()
		p:init_request()

		buf = buf:value()
		local len = 123
		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"GET", "/fa?1=fe&2=fi+%F0%9F%98%AC", 1})
		buf = buf + rc
		len = len - rc

		local headers, buf, len =  parse_headers(p, buf, len, 6)

		local want = {
			["User-Agent"]=USER_AGENT,
			Accept="*/*",
			fo={"fum", "fa", "fe"},
			fi="fo",
		}
		assert.same(headers, want)

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), true)
	end,

	test_encode_request_defaults = function()
		local path = "/"
		local buf = buffer_zero()

		local err = HTTP.encode_request(buf, "GET", path)
		assert(not err)

		local p = HTTP.Parser()
		p:init_request()

		buf = buf:value()
		local len = 65
		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {"GET", "/", 1})
		buf = buf + rc
		len = len - rc

		local headers, buf, len =  parse_headers(p, buf, len, 2)

		local want = {
			["User-Agent"]=USER_AGENT,
			Accept="*/*",
		}
		assert.same(headers, want)

		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), true)
	end,

	test_encode_response = function()
		local headers = {fa="fe", fi="fo", Date="Sun, 18 Oct 2009 08:56:53 GMT"}
		local data = "fum\n"
		local buf = buffer_zero()

		local err = HTTP.encode_response(buf, Status(200), headers, data)
		assert(not err)

		local p = HTTP.Parser()
		p:init_response()

		buf = buf:value()
		local len = 95
		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {200, "OK", 1})
		buf = buf + rc
		len = len - rc

		local headers, buf, len =  parse_headers(p, buf, len, 4)

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
		local buf = buffer_zero()

		local err = HTTP.encode_response(buf, Status(200), headers, 6)
		assert(not err)

		local p = HTTP.Parser()
		p:init_response()

		buf = buf:value()
		local len = 91
		local err, rc = p:next(buf, len)
		assert(rc > 0)
		assert.equal(p:is_done(), false)
		assert.same({p:value(buf)}, {200, "OK", 1})
		buf = buf + rc
		len = len - rc

		local headers, buf, len =  parse_headers(p, buf, len, 4)

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

	test_encode_chunk = function()
		local headers = {fe="fi", Date="Sun, 18 Oct 2009 08:56:53 GMT"}
		local buf = buffer_zero()

		local err = HTTP.encode_response(buf, Status(200), headers)
		assert(not err)

		HTTP.encode_chunk(buf, "fafe")
		HTTP.encode_chunk(buf, "fi")
		HTTP.encode_chunk(buf, "fo")
		HTTP.encode_chunk(buf)

		assert_response_chunk(buf)
	end,

	test_encode_response_map = function()
		local headers = Map()
		headers:add("fe", "fi")
		headers:add("Date", "Sun, 18 Oct 2009 08:56:53 GMT")
		local buf = buffer_zero()

		local err = HTTP.encode_response(buf, Status(200), headers)
		assert(not err)

		HTTP.encode_chunk(buf, "fafe")
		HTTP.encode_chunk(buf, "fi")
		HTTP.encode_chunk(buf, "fo")
		HTTP.encode_chunk(buf)

		assert_response_chunk(buf)
	end,


	test_encode_chunk_push_encode = function()
		local headers = {fe="fi", Date="Sun, 18 Oct 2009 08:56:53 GMT"}
		local buf = buffer_zero()

		local err = HTTP.encode_response(buf, Status(200), headers)
		assert(not err)

		HTTP.encode_chunk(buf, 4)
		buf:push("fafe")
		HTTP.encode_chunk(buf, "fi")
		HTTP.encode_chunk(buf, 2)
		buf:push("fo")
		HTTP.encode_chunk(buf)

		assert_response_chunk(buf)
	end,

	test_encode_chunk_encode_push = function()
		local headers = {fe="fi", Date="Sun, 18 Oct 2009 08:56:53 GMT"}
		local buf = buffer_zero()

		local err = HTTP.encode_response(buf, Status(200), headers)
		assert(not err)

		HTTP.encode_chunk(buf, 4)
		buf:push("fafe")
		HTTP.encode_chunk(buf, 2)
		buf:push("fi")
		HTTP.encode_chunk(buf, "fo")
		HTTP.encode_chunk(buf)

		assert_response_chunk(buf)
	end,

	test_decode_request = function()
		local levee = require("levee")

		local request = "" ..
			"GET /some/path HTTP/1.1\r\n" ..
			"H1: one\r\n" ..
			"H2: two\r\n" ..
			"H2: too\r\n" ..
			"H2: to\r\n" ..
			"Content-Length: 13\r\n" ..
			"\r\n" ..
			"Hello World!\n"

		local h = levee.Hub()
		local r, w = h.io:pipe()
		local stream = r:stream()
		w:write(request)

		local parser = HTTP.Parser()
		local err, req = HTTP.decode_request(parser, stream)
		assert(not err)
		assert.equal(req.method, "GET")
		assert.equal(req.path, "/some/path")
		assert.equal(req.version, 1)
		assert.equal(req.headers["Content-Length"], "13")
		assert.equal(req.headers["H1"], "one")
		assert.same(req.headers["H2"], {"two", "too", "to"})
		assert.equal(req.len, 13)

		assert.equal(ffi.string(stream:value(), req.len), "Hello World!\n")
	end,

	test_decode_request_uri = function()
		local levee = require("levee")

		local request = "" ..
			"GET /fa?fe=fi&fo=fum+%F0%9F%98%AC HTTP/1.1\r\n" ..
			"Host: 127.0.0.1:8000\r\n" ..
			"\r\n"

		local h = levee.Hub()
		local r, w = h.io:pipe()
		local stream = r:stream()
		w:write(request)

		local parser = HTTP.Parser()
		local err, req = HTTP.decode_request(parser, stream)
		local err, uri = req:uri()
		assert(not err)
		assert.equal(uri.host, "127.0.0.1")
		assert.equal(uri.port, "8000")
		local err, params = uri:params()
		assert(not err)
		assert.same(params, {fe="fi", fo="fum 😬"})
	end,

	test_decode_request_uri_no_host = function()
		local levee = require("levee")

		local request = "" ..
			"GET /fa?fe=fi&fo=fum+%F0%9F%98%AC HTTP/1.1\r\n" ..
			"\r\n"

		local h = levee.Hub()
		local r, w = h.io:pipe()
		local stream = r:stream()
		w:write(request)

		local parser = HTTP.Parser()
		local err, req = HTTP.decode_request(parser, stream)
		local err, uri = req:uri()
		assert(not err)
		assert(not uri.host)
		assert(not uri.port)
		local err, params = uri:params()
		assert(not err)
		assert.same(params, {fe="fi", fo="fum 😬"})
	end,

	test_decode_response = function()
		local levee = require("levee")

		local response = "" ..
			"HTTP/1.1 200 OK\r\n" ..
			"Date: Sun, 18 Oct 2009 08:56:53 GMT\r\n" ..
			"Content-Length: 13\r\n" ..
			"H1: one\r\n" ..
			"H2: two\r\n" ..
			"H2: too\r\n" ..
			"H2: to\r\n" ..
			"\r\n" ..
			"Hello World!\n"

		local h = levee.Hub()
		local r, w = h.io:pipe()
		local stream = r:stream()
		w:write(response)

		local parser = HTTP.Parser()
		local err, res = HTTP.decode_response(parser, stream)
		assert(not err)
		assert.equal(res.code, 200)
		assert.equal(res.reason, "OK")
		assert.equal(res.version, 1)
		assert.equal(res.headers["Date"], "Sun, 18 Oct 2009 08:56:53 GMT")
		assert.equal(res.headers["H1"], "one")
		assert.same(res.headers["H2"], {"two", "too", "to"})
		assert.equal(res.headers["Content-Length"], "13")
		assert.equal(res.len, 13)

		assert.equal(ffi.string(stream:value(), res.len), "Hello World!\n")
	end,

	test_decode_chunk = function()
		local levee = require("levee")

		local response = "" ..
			"HTTP/1.1 200 OK\r\n" ..
			"Transfer-Encoding: chunked\r\n"..
			"\r\n" ..
			"2\r\nHe\r\n"..
			"4\r\nllo \r\n"..
			"7\r\nWorld!\n\r\n"..
			"\r\n"

		local h = levee.Hub()
		local r, w = h.io:pipe()
		local stream = r:stream()
		w:write(response)

		local parser = HTTP.Parser()
		HTTP.decode_response(parser, stream)

		local err, n = HTTP.decode_chunk(parser, stream)
		assert(not err)
		assert.equal(ffi.string(stream:value(), n), "He")
		stream:trim(n)

		local err, n = HTTP.decode_chunk(parser, stream)
		assert(not err)
		assert.equal(ffi.string(stream:value(), n), "llo ")
		stream:trim(n)

		local err, n = HTTP.decode_chunk(parser, stream)
		assert(not err)
		assert.equal(ffi.string(stream:value(), n), "World!\n")
		stream:trim(n)

		local err, n = HTTP.decode_chunk(parser, stream)
		assert(not err)
		assert.equal(n, 0)
	end,

	p = {
		content = {
			test_core = function()
				local h = levee.Hub()

				local r, w = h.io:pipe()

				w.p.http:write_request("POST", "/foo", {foo="bar"}, {H1="H1"}, "OH HAI")
				local err, req = r.p.http:read_request()
				local err, uri = req:uri()
				local err, params = uri:params()
				assert.equal(req.method, "POST")
				assert.equal(req.headers["h1"], "H1")
				assert.equal(uri.path, "/foo")
				assert.same(params, {foo="bar"})
				assert.same({r.p:tostring(req.len)}, {nil, "OH HAI"})

				w.p.http:write_response(200, {H2="H2"}, "YARG")
				local err, res = r.p.http:read_response()
				assert.equal(res.code, 200)
				assert.equal(res.headers["h2"], "H2")
				assert.same({r.p:tostring(res.len)}, {nil, "YARG"})
			end,

			test_proxy = function()
				local h = levee.Hub()

				local s1 = {}
				s1.r, s1.w = h.io:pipe()
				local s2 = {}
				s2.r, s2.w = h.io:pipe()

				s1.w.p.http:write_response(200, {H2="H2"}, "YARG")
				local err, res = s1.r.p.http:read_response()
				res.body:proxy(s2.w)
				assert.equal(s2.r:reads(), "YARG")
			end,

			test_json = function()
				local h = levee.Hub()

				local r, w = h.io:pipe()

				local chunks = {
					'{"int": 3, "f',
					'oo": "bar", "neste',
					'd": {"null": null, "alist": ',
					'[1, 2, 3], "yes": tr',
					'ue, "no": false}}{',
					'"foo": "bar"}}', }

				w.p.http:write_response(200, {}, table.concat(chunks))

				local err, res = r.p.http:read_response()
				assert.equal(res.code, 200)

				local value = res.body:json()
				assert.same(value, {
					int = 3,
					foo = "bar",
					nested = {
						alist = {1, 2, 3},
						yes = true,
						no = false, } })
			end,
		},

		chunk = {
			test_core = function()
				local h = levee.Hub()

				local r, w = h.io:pipe()

				-- TODO: test using chunk encoding for request
				w.p.http:write_request("POST", "/foo", {foo="bar"}, {H1="H1"}, "OH HAI")
				local err, req = r.p.http:read_request()
				local err, uri = req:uri()
				local err, params = uri:params()
				assert.equal(req.method, "POST")
				assert.equal(req.headers["h1"], "H1")
				assert.equal(uri.path, "/foo")
				assert.same(params, {foo="bar"})
				assert.same({r.p:tostring(req.len)}, {nil, "OH HAI"})

				-- TODO: with the current write strategy you need to write the first
				-- chunk before the beginning of the request can be read
				-- Not sure how much of a concern that is
				w.p.http:write_response(200, {H2="H2"}, nil)
				w.p.http:write_chunk("YARG")

				local err, res = r.p.http:read_response()
				assert.equal(res.code, 200)
				assert.equal(res.headers["h2"], "H2")
				local err, len = r.p.http:read_chunk()
				assert.same({r.p:tostring(len)}, {nil, "YARG"})

				w.p.http:write_chunk("YARG")
				local err, len = r.p.http:read_chunk()
				assert.same({r.p:tostring(len)}, {nil, "YARG"})

				w.p.http:write_chunk("YARG")
				local err, len = r.p.http:read_chunk()
				assert.same({r.p:tostring(len)}, {nil, "YARG"})

				w.p.http:write_chunk(0)
				local err, len = r.p.http:read_chunk()
				assert.equal(len, 0)
			end,

			test_splice = function()
				local h = levee.Hub()

				local s1 = {}
				s1.r, s1.w = h.io:pipe()
				local s2 = {}
				s2.r, s2.w = h.io:pipe()

				h:spawn(function()
					s1.w.p.http:write_response(200, {})
					for i = 1, 6 do
						s1.w.p.http:write_chunk(("X"):rep(10*1024))
					end
					s1.w.p.http:write_chunk(("X"):rep(4*1024+10))
					s1.w.p.http:write_chunk(0)
				end)

				local err, res = s1.r.p.http:read_response()
				h:spawn(function()
					res.body:splice(s2.w)
					s2.w:close()
				end)

				while true do
					local err = s2.r.p:readin()
					if err then break end
				end

				local err, s = s2.r.p:tostring()
				assert.equal(s, ("X"):rep(64*1024+10))
			end,

			test_proxy = function()
				local h = levee.Hub()

				local s1 = {}
				s1.r, s1.w = h.io:pipe()
				local s2 = {}
				s2.r, s2.w = h.io:pipe()

				s1.w.p.http:write_response(200, {H2="H2"})
				s1.w.p.http:write_chunk("Y")
				s1.w.p.http:write_chunk("A")
				s1.w.p.http:write_chunk("R")
				s1.w.p.http:write_chunk("G")
				s1.w.p.http:write_chunk(0)

				local err, res = s1.r.p.http:read_response()

				s2.w.p.http:write_response(200, {H2="H2"})
				res.body:proxy(s2.w)

				local err, res = s2.r.p.http:read_response()
				local err, s = res.body:tostring()
				assert.equal(s, "YARG")
			end,

			test_proxy_error = function()
				local h = levee.Hub()

				local s1 = {}
				s1.r, s1.w = h.io:pipe()
				local s2 = {}
				s2.r, s2.w = h.io:pipe()

				s1.w.p.http:write_response(200, {H2="H2"})
				s1.w.p.http:write_chunk(50)
				s1.w:write(("X"):rep(25))
				s1.w:close()

				local err, res = s1.r.p.http:read_response()

				s2.w.p.http:write_response(200, {H2="H2"})
				local err = res.body:proxy(s2.w)
				assert.equal(err, levee.errors.http.ESYNTAX)

				local err, res = s2.r.p.http:read_response()
				local err, s = res.body:tostring()
				assert.equal(err, levee.errors.http.ESYNTAX)
			end,

			test_json = function()
				local h = levee.Hub()

				local r, w = h.io:pipe()

				w.p.http:write_response(200, {})
				local chunks = {
					'{"int": 3, "f',
					'oo": "bar", "neste',
					'd": {"null": null, "alist": ',
					'[1, 2, 3], "yes": tr',
					'ue, "no": false}}{',
					'"foo": "bar"}}', }
				for __, chunk in pairs(chunks) do w.p.http:write_chunk(chunk) end

				local err, res = r.p.http:read_response()
				assert.equal(res.code, 200)

				local value = res.body:json()
				assert.same(value, {
					int = 3,
					foo = "bar",
					nested = {
						alist = {1, 2, 3},
						yes = true,
						no = false, } })
			end,
		},

		test_complex = function()
			local h = levee.Hub()

			local BODY = ("X"):rep(64*1024+10)

			local err, serve = h.stream:listen()
			serve:spawn_every(function(conn)
				for req in conn.p.http do
					if req.path == "/content" then
						conn.p.http:write_response(200, {}, BODY)
					else
						conn.p.http:write_response(200, {})
						for i = 1, 6 do
							conn.p.http:write_chunk(("X"):rep(10*1024))
						end
						conn.p.http:write_chunk(("X"):rep(4*1024+10))
						conn.p.http:write_chunk(0)
					end
				end
			end)

			local err, up = h.stream:connect(serve:port())

			-- TODO: think through error handling
			local err, proxy = h.stream:listen()
			proxy:spawn_every(function(down)
				for req in down.p.http do
					local err, res = up.p.http:get(req.path, {headers=req.headers})
					down.p.http:write_response(res.code, res.headers)
					res.body:proxy(down)
				end
			end)

			local err, conn = h.stream:dial(proxy:port())

			local err, res = conn.p.http:get("/content")
			assert.equal(res.code, 200)
			assert.same({res.body:tostring()}, {nil, BODY})

			local err, res = conn.p.http:get("/chunked")
			assert.equal(res.code, 200)
			assert.same({res.body:tostring()}, {nil, BODY})

			local function cat(path)
				local f = io.open(path, "rb")
				local content = f:read("*all")
				f:close()
				return content
			end

			local tmp = os.tmpname()
			defer(function() os.remove(tmp) end)

			os.remove(tmp)
			local err, res = conn.p.http:get("/content")
			assert.equal(res.code, 200)
			res.body:save(tmp)
			assert.equal(cat(tmp), BODY)

			os.remove(tmp)
			local err, res = conn.p.http:get("/chunked")
			assert.equal(res.code, 200)
			res.body:save(tmp)
			assert.equal(cat(tmp), BODY)
		end,
	},
}
