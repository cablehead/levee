return {
	test_core = function()
		local levee = require("levee")
		levee.run(function(h)
			print()
			print()

			local serve = h.http:listen(8000)
			print(serve)

			local s1 = serve:recv()
			print(s1)

			local req = s1:recv()
			print(req.method, req.path)

		end)
	end,
}
