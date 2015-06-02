return {
	test_pipe = function()
		local h = require("levee").Hub()

		local p = h:pipe()

		-- send and then recv
		h:spawn_later(10, function() p:send("1") end)
		assert.equal(p:recv(), "1")

		-- recv and then send
		local state
		h:spawn(function() state = p:recv() end)
		h:sleep(1)
		p:send("2")
		h:sleep(1)
		assert.equal(state, "2")
	end,
}
