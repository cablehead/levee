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

	test_middle_and_end = function()
		print()
		print()

		local message = require("levee.message")

		local foo = message.Foo()

		collectgarbage("collect")
		print(foo.sender.index, foo.sender.other.index)
		print(foo.recver.index, foo.recver.other.index)

		local sender, recver = unpack(foo)

		foo = nil
		collectgarbage("collect")
		print(sender.index, sender.other.index)
		print(recver.index, recver.other.index)

		print()
		recver = nil
		collectgarbage("collect")
		print(sender.index, sender.other)

		print()
		sender = nil
		collectgarbage("collect")

		print()
	end,
}
