local sys = require("levee.sys")

return {
	test_core = function()
		local r, w = sys.os.pipe()
		local poller = sys.poller()

		poller:register(r, true)
		poller:register(w, false, true)

		local events, n = poller:poll()
		assert.equal(n, 1)
		assert.same({w, false, true, false}, {events[0]:value()})

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
