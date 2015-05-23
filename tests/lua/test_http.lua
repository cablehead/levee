return {
	test_core = function()
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
}
