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
}
