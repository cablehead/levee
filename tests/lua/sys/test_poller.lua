local sys = require("levee.sys")

return {
	test_core = function()
		local r, w = sys.os.pipe()
		local poller = sys.poller.Poller()

		poller:register(r, true)
		poller:register(w, false, true)

		assert.same({w, false, true, false}, {poller:poll():value()})

		sys.os.write(w, "foo")
		assert.same({w, false, true, false}, {poller:poll():value()})
		assert.same({r, true, false, false}, {poller:poll():value()})

		sys.os.close(w)
		assert.same({r, true, false, true}, {poller:poll():value()})

		poller:unregister(r, true)
		poller:unregister(w, false, true)
	end,
}
