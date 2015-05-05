return {
	test_time = function()
		local time = require("levee.time")

		local a = time.Time(100)
		local b = time.Time(200)
		assert((a + b) == time.Time(300))
		assert((a - b) == time.Time(-100))
		assert((b - a) == time.Time(100))

	end,
}
