return {
	test_core = function()
		local levee = require("levee")
		levee.run(function(h)
			print()
			print()

			local serve = h.http:listen(8000)

			--[[
			c1 = h.tcp:connect(8000)
			c1:send(
				"GET /path HTTP/1.1\r\n" ..
				"H1: one\r\n" ..
				"\r\n")
			--]]
			--

			function handle(conn)
				while true do
					local req = conn:recv()
					req.reply({200, "OK"}, {}, "Hello World\n")
				end
			end

			while true do
				local conn = serve:recv()
				h:spawn(handle, conn)
			end

		end)
	end,
}
