return {
	test_pipe = function()
		local levee = require("levee")

		levee.run(function(h)
			local p = h:pipe()
			local done = h:pipe()

			-- test recv and then send
			h:spawn(function() p:send("1") end)
			local got = p:recv()
			assert(got == "1")

			-- test send and then recv
			h:spawn(function()
				local got = p:recv()
				assert(got == "2")
				done:send()
			end)
			p:send("2")

			done:recv()
		end)
	end,
}
