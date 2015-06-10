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
		assert.equal(req.body:recv(), nil)

		req.response:send({levee.http.Status(200), {}, "Hello world\n"})

		response = response:recv()
		assert.equal(response.code, 200)

		local body = response.client.buf:take_s()
		assert.equal(#body, response.len)
		assert.equal(body, "Hello world\n")
		response.client.baton:resume()

		-- make another request on the same connection

		local response = c:get("/path")

		local req = s:recv()
		assert.equal(req.method, "GET")
		assert.equal(req.path, "/path")
		assert.equal(req.body:recv(), nil)

		req.response:send({levee.http.Status(200), {}, "Hello world\n"})

		response = response:recv()
		assert.equal(response.code, 200)

		local body = response.client.buf:take_s()
		assert.equal(#body, response.len)
		assert.equal(body, "Hello world\n")
		response.client.baton:resume()

		c:close()
		serve:close()
		h:sleep(1)
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

		local body = req.serve.buf:take_s()
		assert.equal(#body, req.len)
		assert.equal(body, "foo")
		req.serve.baton:resume()

		req.response:send({levee.http.Status(200), {}, "Hello world\n"})

		if true then return end

		response = response:recv()
		assert.equal(response.code, 200)

		local body = response.client.buf:take_s()
		assert.equal(#body, response.len)
		assert.equal(body, "Hello world\n")
		response.client.baton:resume()

		c:close()
		serve:close()
		h:sleep(1)
		assert.same(h.registered, {})
	end,

	test_chunk_transfer = function()
		if true then return "SKIP" end
		local levee = require("levee")

		local h = levee.Hub()

		local serve = h.http:listen(8000)
		local c = h.http:connect(8000)
		local s = serve:recv()

		local response = c:get("/path")
		local req = s:recv()
		local stream = h:pipe()
		req:reply(levee.http.Status(200), {}, stream)

		response = response:recv()
		assert.equal(response.code, 200)

		stream:send("01234567012345678")
		assert.equal(response.body:recv(), "01234567012345678")

		stream:send("90123456701234567")
		assert.equal(response.body:recv(), "90123456701234567")

		stream:close()
		assert.equal(response.body:recv(), nil)

		c:close()
		serve:close()
		h:sleep(1)
		assert.same(h.registered, {})
	end,
}
