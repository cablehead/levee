return {
	test_core = function()
		if true then return 'SKIP' end
		local levee = require("levee")
		levee.run(function(h)
			local serve = h.tcp:listen(8000)

			local c1 = h.tcp:connect(8000)
			local s1 = serve:recv()

			collectgarbage("collect")

			c1:send("m1.1")
			assert(s1:recv():take_s() == "m1.1")

			local c2 = h.tcp:connect(8000)
			local s2 = serve:recv()
			c2:send("m2.1")
			assert(s2:recv():take_s() == "m2.1")

			s1:send("m1.2")
			assert(c1:recv():take_s() == "m1.2")

			s2:send("m2.2")
			assert(c2:recv():take_s() == "m2.2")

			c1:close()
			c2:close()
			serve:close()
		end)
	end,
}
