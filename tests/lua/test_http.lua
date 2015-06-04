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

		local iov = levee.iovec.Iovec(4)
		iov:write(request)
		c:send(iov)
		iov:reset()

		local s = serve:recv()

		local req = s:recv()

		assert.equal(req.method, "GET")
		assert.equal(req.path, "/some/path")
		assert.same(req.headers, {H1 = "one"})

		req:reply("HTTP/1.1 200 OK\r\n", {}, "Hello world\n")
		assert(#c:recv():take_s() > 0)
	end,

	test_core = function()
		if true then return 'SKIP' end
		local levee = require("levee")
		levee.run(function(h)
			local serve = h.http:listen(8000)

			local c = h.http:connect(8000)

			local response = c:get("/path")

			local s = serve:recv()

			local req = s:recv()
			assert.equal(req.method, "GET")
			assert.equal(req.path, "/path")
			assert.equal(req.body, nil)
			req.reply({200, "OK"}, {}, "Hello World\n")

			response = response:recv()
			assert.equal(response.code, 200)
			assert.equal(response.body, "Hello World\n")

			-- make another request on the same connection

			local response = c:get("/path")

			local req = s:recv()
			assert.equal(req.method, "GET")
			assert.equal(req.path, "/path")
			assert.equal(req.body, nil)
			req.reply({200, "OK"}, {}, "Hello World\n")

			response = response:recv()
			assert.equal(response.code, 200)
			assert.equal(response.body, "Hello World\n")

			c:close()
			serve:close()
		end)
	end,

	test_post = function()
		if true then return 'SKIP' end
		local levee = require("levee")
		levee.run(function(h)
			local serve = h.http:listen(8000)

			local c = h.http:connect(8000)

			local response = c:post("/path", {data="foo"})

			local s = serve:recv()

			local req = s:recv()
			assert.equal(req.method, "POST")
			assert.equal(req.path, "/path")
			assert.equal(req.body, "foo")
			req.reply({200, "OK"}, {}, "foobar")

			response = response:recv()
			assert.equal(response.code, 200)
			assert.equal(response.body, "foobar")

			c:close()
			serve:close()
		end)
	end,

	test_serve = function()
		if true then return 'SKIP' end
		local levee = require("levee")
		levee.run(function(h)
			local serve = h.http:listen(8000)

			function handle(conn)
				for req in conn do
					req.reply({200, "OK"}, {}, "Hello world\n")
				end
			end

			h:spawn(function()
				for conn in serve do
					h:spawn(handle, conn)
				end
			end)

			local c = h.http:connect(8000)

			for _ = 1, 10 do
				local response = c:get("/path"):recv()
				assert.equal(response.code, 200)
				assert.equal(response.body, "Hello world\n")
			end

			c:close()
			serve:close()
		end)
	end,
}
