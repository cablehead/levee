local levee = require("levee")


return {
	test_capture = function()
		local h = levee.Hub()

		local child = h.process:spawn("cat")

		child.stdin:write("foo")
		assert.equal(child.stdout:reads(), "foo")

		child.stdin:close()
		local err, p = child.done:recv()
		assert.equal(p:running(), false)
	end,

	test_to_fd = function()
		local h = levee.Hub()

		local r1, w1 = sys.os.pipe()
		local r2, w2 = sys.os.pipe()

		local child = h.process:spawn("cat", {io={STDIN=r1, STDOUT=w2}})

		sys.os.write(w1, "foo")
		assert.equal("foo", sys.os.reads(r2))

		C.close(w1)
		child.done:recv()
	end,

	test_to_socket = function()
		local h = levee.Hub()

		local serve = h.tcp:listen()
		local c1 = h.tcp:connect(serve:addr():port())
		local s1 = serve:recv()

		local child = h.process:spawn("cat", {io={STDIN=s1}})

		c1:write("foo")
		assert.equal(child.stdout:reads(), "foo")

		c1:close()
		child.done:recv()
	end,

	test_argv = function()
		local h = levee.Hub()

		local child = h.process:spawn("echo", {argv={"foo", "bar"}})
		assert.equal(child.stdout:reads(), "foo bar\n")

		child.done:recv()
	end,

	test_close = function()
		local h = levee.Hub()
		local child = h.process:spawn("echo", {argv={"foo"}, io={STDIN=-1}})
		assert.equal(child.stdout:reads(), "foo\n")
		child.done:recv()
	end,

	test_default = function()
		-- test leaving child processes stdin/out mapped to the parents
		-- skipping as it's not really practical to run automatically
		if true then return "SKIP" end
		print()
		print()
		local h = levee.Hub()

		local serve = h.tcp:listen()
		local c1 = h.tcp:connect(serve:addr():port())
		local s1 = serve:recv()

		local child = h.process:spawn("cat", {io={STDIN=0, STDOUT=1}})
		child.done:recv()
		print()
	end,
}
