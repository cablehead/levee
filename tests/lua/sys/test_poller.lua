local ffi = require('ffi')

local sys = require("levee.sys")
local time = require("levee.time")


local function rel_to_abs(ms)
		local t = time.now()
		return ffi.new(
			"int64_t", (t.tv_sec * 1000ULL) + (t.tv_usec / 1000ULL)) + ms
end


return {
	test_core = function()
		local r, w = sys.os.pipe()
		local poller = sys.poller()

		poller:register(r, true)
		poller:register(w, false, true)

		local events, n = poller:poll()
		assert.equal(n, 1)
		assert.same({w, false, true, false}, {events[0]:value()})

		local events, n = poller:poll(rel_to_abs(100))
		assert.equal(n, 0)

		sys.os.write(w, "foo")
		local events, n = poller:poll()
		assert(n <= 2)
		assert.same({r, true, false, false}, {events[n-1]:value()})


		sys.os.close(w)
		local events, n = poller:poll()
		assert.equal(n, 1)
		assert.same({r, true, false, true}, {events[0]:value()})

		poller:unregister(r, true)
		poller:unregister(w, false, true)
	end,
}
