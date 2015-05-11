local sys = require("levee.sys")

return {
	test_core = function()
		local r, w = sys.os.pipe()
		local poller = sys.poller.Poller()

		poller:register(r, true)
		poller:register(w, false, true)

		assert.same({poller:poll()}, {w, sys.poller.POLLOUT})

		sys.os.write(w, "foo")
		assert.same({poller:poll()}, {r, sys.poller.POLLIN})

		sys.os.close(w)
		assert.same({poller:poll()}, {r, sys.poller.POLLERR})

		poller:unregister(r, true)
		poller:unregister(w, false, true)
	end,
}
