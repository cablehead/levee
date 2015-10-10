local levee = require("levee")

return {
	test_encode = function()
		print()
		print()
		local buf = levee.msgpack.encode({
			foo = "bar",
			arr = {3, "foo", true, false, 3.7},
		})

		print(#buf)

		print()
		print()
	end,
}
