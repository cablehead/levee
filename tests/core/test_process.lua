local levee = require("levee")
local _ = levee._


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

		local r1, w1 = _.pipe()
		local r2, w2 = _.pipe()

		local child = h.process:spawn("cat", {io={STDIN=r1, STDOUT=w2}})

		_.write(w1, "foo")
		assert.equal("foo", _.reads(r2))

		_.close(w1)
		child.done:recv()
	end,

	test_to_socket = function()
		if true then return "SKIP" end
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

	test_gc = function()
		local h = levee.Hub()
		local child = h.process:spawn("cat")
		local pid = child.pid
		assert.same({_.waitpid(pid, C.WNOHANG)}, {nil, 0, 0, 0})

		child = nil
		local options = bit.bor(C.WUNTRACED, C.WCONTINUED)
		collectgarbage("collect")
		collectgarbage("collect")
		assert.same({_.waitpid(pid, options)}, {nil, pid, 0, 15})
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

	test_respawn = function()
		local script = [[
			local levee = require("levee")
			local _ = levee._

			local h = levee.Hub()

			if arg[1] then
				io.stdout:write(arg[1])
			else
				local child = h.process:respawn({argv={"child"}})
				io.stdout:write(child.stdout:reads())
				child.done:recv()
			end
		]]

		local tmp = _.path.Path:tmpdir()
		defer(function() tmp:remove(true) end)

		tmp("foo.lua"):write(script)

		local options = {
			exe = tostring(tmp("foo")),
			file = tostring(tmp("foo.lua")), }

		require("levee.cmd").build.run(options)

		local h = levee.Hub()

		local child = h.process:respawn({argv={"run", options.file}})
		assert.equal(child.stdout:reads(), "child")
		child.done:recv()

		local child = h.process:spawn(options.exe)
		assert.equal(child.stdout:reads(), "child")
		child.done:recv()
	end,
}
