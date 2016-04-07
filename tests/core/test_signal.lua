local ffi = require('ffi')
local C = ffi.C


local levee = require("levee")


return {
	test_core = function()
		local h = levee.Hub()

		local r1 = h:signal(C.SIGALRM, C.SIGTERM)
		local r2 = h:signal(C.SIGALRM)

		local pid = C.getpid()

		C.kill(pid, C.SIGALRM)
		assert.same({r1:recv()}, {nil, C.SIGALRM})
		assert.same({r2:recv()}, {nil, C.SIGALRM})

		C.kill(pid, C.SIGTERM)
		assert.same({r1:recv()}, {nil, C.SIGTERM})
		assert.same({r2:recv(10)}, {levee.errors.TIMEOUT})

		r1:close()
		C.kill(pid, C.SIGALRM)
		assert.same({r1:recv()}, {levee.errors.CLOSED})
		assert.same({r2:recv()}, {nil, C.SIGALRM})

		r2:close()
		assert(not h:in_use())
		assert.same(h.signal.reverse, {})

		-- C.kill(pid, C.SIGALRM)
	end,
}
