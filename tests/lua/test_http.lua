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

		req:reply(levee.http.Status(200), {}, "Hello world\n")
		assert(#c:recv():take_s() > 0)

		s:close()
		serve:close()
		h:sleep(1)
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
		req:reply(levee.http.Status(200), {}, "Hello World\n")

		response = response:recv()
		assert.equal(response.code, 200)
		assert.equal(response.body:recv(), "Hello World\n")

		-- make another request on the same connection

		local response = c:get("/path")

		local req = s:recv()
		assert.equal(req.method, "GET")
		assert.equal(req.path, "/path")
		assert.equal(req.body:recv(), nil)
		req:reply(levee.http.Status(200), {}, "Hello World\n")

		response = response:recv()
		assert.equal(response.code, 200)
		assert.equal(response.body:recv(), "Hello World\n")

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
		assert.equal(req.body:recv(), "foo")
		req:reply(levee.http.Status(200), {}, "foobar")

		response = response:recv()
		assert.equal(response.code, 200)
		assert.equal(response.body:recv(), "foobar")

		c:close()
		serve:close()
		h:sleep(1)
		assert.same(h.registered, {})
	end,
}
