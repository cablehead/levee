local ffi = require('ffi')

return {
	test_basic = function()
		local request = "" ..
			"GET /some/path HTTP/1.1\r\n" ..
			"H1: one\r\n" ..
			"\r\n"

		local levee = require("levee")

		local h = levee.Hub()
		local serve = h.http:listen(8000)

		local c = h.tcp:connect(8000)
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

		local serve = h.http:listen(8000)

		local c = h.http:connect(8000)
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
		local serve = h.http:listen(8000)
		local c = h.http:connect(8000)
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

		local serve = h.http:listen(8000)

		local c = h.http:connect(8000)
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
		assert.equal(response.body:tostring(), "Hello world\n")

		c:close()
		serve:close()
		assert.same(h.registered, {})
	end,

	test_chunk_transfer = function()
		local levee = require("levee")

		local h = levee.Hub()

		local serve = h.http:listen(8000)
		local c = h.http:connect(8000)
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
}
