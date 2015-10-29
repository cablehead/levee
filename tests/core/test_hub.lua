local ffi = require("ffi")

local levee = require("levee")
local _ = levee._


return {
	test_spawn = function()
		local h = levee.Hub()

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

	test_spawn_later = function()
		local h = levee.Hub()

		local trace = {}

		h:spawn_later(30, function() table.insert(trace, {"f"}) end)

		table.insert(trace, {"m", 1})
		h:sleep(20)
		table.insert(trace, {"m", 2})
		h:sleep(20)
		table.insert(trace, {"m", 3})

		assert.same(trace, {
			{"m", 1},
			{"m", 2},
			{"f"},
			{"m", 3}, })
	end,

	test_coro = function()
		local h = levee.Hub()

		local trace = {}
		local coros = {}

		local function f(no)
			table.insert(trace, {"f", no, 1})
			coros[no] = coroutine.running()
			local err, value = h:pause()
			table.insert(trace, {"f", no, 2, err, value})
		end

		table.insert(trace, {"m", 1})
		h:spawn(f, 1)

		table.insert(trace, {"m", 2})
		h:spawn(f, 2)

		table.insert(trace, {"m", 3})
		h:switch_to(coros[2], "e2", "v2")

		table.insert(trace, {"m", 4})
		h:resume(coros[1], "e1", "v1")
		table.insert(trace, {"m", 5})
		h:continue()

		table.insert(trace, {"m", 6})

		assert.same(trace, {
			{"m", 1},
			{"f", 1, 1},
			{"m", 2},
			{"f", 2, 1},
			{"m", 3},
			{"f", 2, 2, "e2", "v2"},
			{"m", 4},
			{"m", 5},
			{"f", 1, 2, "e1", "v1"},
			{"m", 6}, })
	end,

	test_register = function()
		local h = levee.Hub()
		local err, r, w = _.pipe()

		local r_ev = h:register(r, true)
		local _, w_ev = h:register(w, false, true)

		-- assert timeout as well
		local err, no = w_ev:recv(2000)
		print(err, no)
		assert.equal(no, 1)
		local err, no = w_ev:recv(20)
		print(err, no)
		assert(err.is_levee_timeout)

		os.write(w, "foo")

		-- linux requires a read until writable will signal again
		if ffi.os:lower() ~= "linux" then
			assert.equal(w_ev:recv(), 1)
		end

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
		local h = levee.Hub()
		local abs = h.poller:abstime(100LL)
		local rel = h.poller:reltime(abs)
		assert.equal(100LL, rel)
	end,
	
	test_sleep = function()
		local h = levee.Hub()
		local start = time.now()
		h:sleep(100)
		local stop = time.now()
		local diff = (stop - start):seconds()
		assert(diff > 0.09 and diff < 0.11, diff)
	end,
}
