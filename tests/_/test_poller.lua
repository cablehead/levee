local _ = require("levee")._


return {
	test_core = function()
		local err, r, w = _.pipe()
		local poller = _.poller()

		poller:register(r, true)
		poller:register(w, false, true)

		local err, events, n = poller:poll()
		assert.equal(n, 1)
		assert.same({w, false, false, false, true, false}, {events[0]:value()})

		local err, events, n = poller:poll(poller:reltime(100))
		assert.equal(n, 0)

		_.write(w, "foo")
		local err, events, n = poller:poll()
		assert(n <= 2)
		assert.same({r, false, false, true, false, false}, {events[n-1]:value()})

		_.close(w)
		local err, events, n = poller:poll()
		assert.equal(n, 1)
		assert.same({r, false, false, true, false, true}, {events[0]:value()})

		poller:unregister(r, true)
		poller:unregister(w, false, true)
	end,
}
