local ffi = require('ffi')
local C = ffi.C

local levee = require("levee")
local sys = levee.sys


return {
	test_capture = function()
		local h = levee.Hub()

		local child = h.process:spawn("cat")

		child.stdin:write("foo")
		assert.equal(child.stdout:reads(), "foo")

		child.stdin:close()
		child.done:recv()
	end,

	test_to_fd = function()
		local h = levee.Hub()

		local r1, w1 = sys.os.pipe()
		local r2, w2 = sys.os.pipe()

		local child = h.process:spawn("cat", {io = {STDIN=r1, STDOUT=w2}})

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

		sys.os.block(s1.no)
		local child = h.process:execlp({STDIN=s1.no, STDOUT=C.CAPTURE}, "cat")

		c1:write("foo")
		assert.equal(child.stdout:reads(), "foo")

		c1:close()
		child.done:recv()
	end,
}
