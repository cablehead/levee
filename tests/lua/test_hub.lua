return {
	test_spawn = function()
		local h = require("levee").Hub()

		local beats = {}

		h:spawn(function()
			for i = 1, 2 do
				h:sleep(100)
				table.insert(beats, "tick")
			end
		end)

		h:sleep(50)

		for i = 1, 2 do
			h:sleep(100)
			table.insert(beats, "tock")
		end

		assert.same(beats, {"tick", "tock", "tick", "tock"})
	end,

	test_register = function()
		local levee = require("levee")

		local h = levee.Hub()

		local r, w = levee.sys.os.pipe()

		local events = h:register(w, false, true)
		assert.same(events:recv(), {false, true, false})
	end,
}
