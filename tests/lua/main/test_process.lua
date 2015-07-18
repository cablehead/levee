local ffi = require('ffi')
local C = ffi.C

local levee = require("levee")
local sys = levee.sys


return {
	test_core = function()
		print()
		print()

		local h = levee.Hub()

		local c = h.process:execlp("cat")

		sys.os.write(c.stdin, "foo")
		print(sys.os.reads(c.stdout))

		C.close(c.stdin)

		c.done:recv()

		print()
		print"----"
		print(c)
		print()
	end,
}
