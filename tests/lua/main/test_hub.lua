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

		-- TODO:
		-- OSX signals write ready after a previous write
		-- I *think* Linux won't signal write ready until EAGAIN has been triggered
		--
		-- assert.equal(w_ev:recv(), 1)

		assert.equal(r_ev:recv(), 1)

		os.close(w)
		assert.equal(r_ev:recv(), -1)

		h:unregister(r, true)
		h:unregister(w, false, true)

		assert.same(h.registered, {})
		assert.equal(r_ev:recv(), -1)
		assert.equal(w_ev:recv(), -1)
	end,

	test_times = function()
		local levee = require("levee")
		local h = levee.Hub()
		local abs = h.poller:abstime(100LL)
		local rel = h.poller:reltime(abs)
		assert.equal(100LL, rel)
	end,
	
	test_sleep = function()
		local ffi = require("ffi")
		local levee = require("levee")
		local time = require("levee.time")
		local h = levee.Hub()
		local start = time.now()
		h:sleep(100)
		local stop = time.now()
		local diff = (stop - start):seconds()
		assert(diff > 0.09 and diff < 0.11, diff)
	end,
}
