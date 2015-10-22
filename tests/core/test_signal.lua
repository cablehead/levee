local ffi = require('ffi')
local C = ffi.C


return {
	test_core = function()
		local h = require("levee").Hub()

		local r1 = h:signal(C.SIGALRM, C.SIGTERM)
		local r2 = h:signal(C.SIGALRM)

		local pid = C.getpid()

		C.kill(pid, C.SIGALRM)
		assert.equal(r1:recv(), C.SIGALRM)
		assert.equal(r2:recv(), C.SIGALRM)

		C.kill(pid, C.SIGTERM)
		assert.equal(r1:recv(), C.SIGTERM)

		r1:close()
		C.kill(pid, C.SIGALRM)
		assert.equal(r2:recv(), C.SIGALRM)

		r2:close()

		assert.same(h.signal.registered, {})
		assert.same(h.signal.reverse, {})

		-- C.kill(pid, C.SIGALRM)
	end,
}
