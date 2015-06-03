return {
	test_pipe = function()
		local h = require("levee").Hub()
		local p = h:pipe()

		-- recv and then send
		h:spawn_later(10, function() p:send("1") end)
		assert.equal(p:recv(), "1")

		-- send and then recv
		local state
		h:spawn(function() state = p:recv() end)
		p:send("2")
		h:sleep(1)
		assert.equal(state, "2")
	end,

	test_iter = function()
		local h = require("levee").Hub()
		local p = h:pipe()

		h:spawn(
			function()
				for i = 1, 3 do
					p:send(i)
				end
				p:close()
			end)

		local want = 1
		for i in p do
			assert.equal(want, i)
			want = want + 1
		end
	end,
}
