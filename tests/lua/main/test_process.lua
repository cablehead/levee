local ffi = require('ffi')
local C = ffi.C

local levee = require("levee")



return {
	test_core = function()
		print()
		print()

		local h = levee.Hub()

		local c1 = h.process:execlp("ls", "-l")
		print("parent", C.getpid(), "->", c1)

		local c2 = h.process:execlp("ls", "-l", "apps")
		print("parent", C.getpid(), "->", c2)

		c1.done:recv()
		c2.done:recv()

		print(c1)
		print(c2)
	end,
}
