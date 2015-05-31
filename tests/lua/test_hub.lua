return {
	test_spawn = function()
		print()
		print()

		local h = require("levee").Hub()

		h:spawn(function()
			while true do
				h:sleep(1000)
				print("tick")
			end
		end)

		h:sleep(500)

		while true do
			h:sleep(1000)
			print("tock")
		end

		print()
	end,
}
