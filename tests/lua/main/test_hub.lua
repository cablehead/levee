return {
	test_spawn = function()
		local h = require("levee").Hub()

		local beats = {}

		h:spawn(function()
			for i = 1, 2 do
				h:sleep(10)
				table.insert(beats, "tick")
			end
		end)

		for i = 1, 2 do
			h:sleep(10)
			table.insert(beats, "tock")
		end

		assert.same(beats, {"tick", "tock", "tick", "tock"})
	end,

	test_register = function()
		local levee = require("levee")
		local os = levee.sys.os

		local h = levee.Hub()

		local r, w = os.pipe()

		local r_ev = h:register(r, true)
		local _, w_ev = h:register(w, false, true)

		assert.equal(w_ev:recv(), 1)

		os.write(w, "foo")
		assert.equal(w_ev:recv(), 1)
		assert.equal(r_ev:recv(), 1)

		os.close(w)
		assert.equal(r_ev:recv(), -1)

		h:unregister(r, true)
		h:unregister(w, false, true)

		assert.same(h.registered, {})
		assert.equal(r_ev:recv(), -1)
		assert.equal(w_ev:recv(), -1)
	end,
}
