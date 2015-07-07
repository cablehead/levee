local ffi = require('ffi')

return {
	test_basic = function()
		local request = "" ..
			"GET /some/path HTTP/1.1\r\n" ..
			"H1: one\r\n" ..
			"\r\n"

		local levee = require("levee")

		local h = levee.Hub()
		local serve = h.http:listen()

		local c = h.tcp:connect(serve:addr():port())
		c:write(request)

		local s = serve:recv()
		local req = s:recv()
		assert.equal(req.method, "GET")
		assert.equal(req.path, "/some/path")
		assert.same(req.headers, {H1 = "one"})

		req.response:send({levee.http.Status(200), {}, "Hello world\n"})

		local buf = levee.buffer(4096)
		assert(c:readinto(buf) > 0)

		s:close()
		serve:close()
		c:readinto(buf)
		assert.same(h.registered, {})
	end,

	test_core = function()
		local levee = require("levee")

		local h = levee.Hub()

		local serve = h.http:listen()

		local c = h.http:connect(serve:addr():port())
		local response = c:get("/path")

		local s = serve:recv()

		local req = s:recv()
		assert.equal(req.method, "GET")
		assert.equal(req.path, "/path")
		req.response:send({levee.http.Status(200), {}, "Hello world\n"})

		response = response:recv()
		assert.equal(response.code, 200)
		assert.equal(response.body:tostring(), "Hello world\n")

		-- make another request on the same connection

		local response = c:get("/path")

		local req = s:recv()
		assert.equal(req.method, "GET")
		assert.equal(req.path, "/path")

		req.response:send({levee.http.Status(200), {}, "Hello world\n"})

		response = response:recv()
		assert.equal(response.code, 200)
		assert.equal(response.body:tostring(), "Hello world\n")

		c:close()
		serve:close()
		assert.same(h.registered, {})
	end,

	test_post = function()
		local levee = require("levee")

		local h = levee.Hub()
		local serve = h.http:listen()
		local c = h.http:connect(serve:addr():port())
		local s = serve:recv()

		local response = c:post("/path", {data="foo"})

		local req = s:recv()

		assert.equal(req.method, "POST")
		assert.equal(req.path, "/path")
		assert.equal(req.body:tostring(), "foo")

		req.response:send({levee.http.Status(200), {}, "Hello world\n"})

		response = response:recv()
		assert.equal(response.code, 200)
		assert.equal(response.body:tostring(), "Hello world\n")

		c:close()
		serve:close()
		assert.same(h.registered, {})
	end,

	test_content_length = function()
		local levee = require("levee")

		local h = levee.Hub()

		local serve = h.http:listen()

		local c = h.http:connect(serve:addr():port())
		local response = c:get("/path")

		local s = serve:recv()

		local req = s:recv()
		assert.equal(req.method, "GET")
		assert.equal(req.path, "/path")

		local body = "Hello world\n"
		req.response:send({levee.http.Status(200), {}, #body})

		response = response:recv()
		assert.equal(response.code, 200)

		req.conn:write(body)
		req.response:close()
		assert.equal(response.body:tostring(), "Hello world\n")

		c:close()
		serve:close()
		assert.same(h.registered, {})
	end,

	test_chunk_transfer = function()
		local levee = require("levee")

		local h = levee.Hub()

		local serve = h.http:listen()
		local c = h.http:connect(serve:addr():port())
		local s = serve:recv()

		local response = c:get("/path")
		local req = s:recv()

		req.response:send({levee.http.Status(200), {}, nil})

		response = response:recv()
		assert.equal(response.code, 200)
		assert(not response.body)
		assert(response.chunks)

		-- send chunk 1
		req.response:send(17)
		req.conn:write("01234567012345678")

		local chunk = response.chunks:recv()
		assert.equal(chunk:tostring(), "01234567012345678")

		-- send chunk 2
		req.response:send("90123456701234567")
		local chunk = response.chunks:recv()
		assert.equal(chunk:tostring(), "90123456701234567")

		-- end response
		req.response:close()
		assert.equal(response.chunks:recv(), nil)

		c:close()
		serve:close()
		assert.same(h.registered, {})
	end,

	test_proxy = function()
		local function x(s, n)
			ret = ""
			for _ = 1, n do
				ret = ret .. s
			end
			return ret
		end

		local levee = require("levee")

		local h = levee.Hub()

		-- origin
		local origin = h.http:listen()
		h:spawn(function()
			for conn in origin do
				h:spawn(function()
					for req in conn do
						req.response:send({levee.http.Status(200), {}, 10000})
						for i = 1, 10 do
							req.conn:write(x(".", 1000))
							h:continue()
						end
						req.response:close()
					end
				end)
			end
		end)

		-- proxy
		local proxy = h.http:listen()
		h:spawn(function()
			for conn in proxy do
				h:spawn(function()
					local backend = h.http:connect(origin:addr():port())
					for req in conn do
						local res = backend:get(req.path):recv()
						req.response:send({levee.http.Status(res.code), {}, #res.body})
						res.body:splice(req.conn)
						req.response:close()
					end
					backend:close()
				end)
			end
		end)

		-- client
		local c = h.http:connect(proxy:addr():port())

		local response = c:get("/"):recv()
		assert.equal(response.code, 200)
		assert(#response.body:tostring() == 10000)

		local response = c:get("/"):recv()
		assert.equal(response.code, 200)
		assert(#response.body:tostring() == 10000)

		c:close()
		proxy:close()
		origin:close()
		h:sleep(100)
		assert.same(h.registered, {})
	end,

	test_sendfile = function()
		local levee = require("levee")

		local h = levee.Hub()

		local serve = h.http:listen()
		h:spawn(function()
			for conn in serve do
				h:spawn(function()
					for req in conn do
						-- TODO: sanitize path
						req:sendfile(req.path)
					end
				end)
			end
		end)

		local c = h.http:connect(serve:addr():port())

		local res = c:get("/foo"):recv()
		assert.equal(res.code, 404)
		assert.equal(res.body:tostring(), "Not Found\n")

		local filename = debug.getinfo(1, 'S').source:sub(2)
		local res = c:get(filename):recv()
		assert.equal(res.code, 200)
		assert(res.body:tostring():find("wombat"))

		c:close()
		serve:close()
		assert.same(h.registered, {})
	end,

	test_connect_fail = function()
		local levee = require("levee")
		local h = levee.Hub()
		local conn, err = h.http:connect(50000)
		assert(not conn)
	end,
}

