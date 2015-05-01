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

	test_pipe_gc = function()
		local message = require("levee.message")
		local p = message.Pipe()
		if true then return end

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

	test_coro = function()
		local ffi = require("ffi")
		local coro = require("coro")

		ffi.cdef[[
			typedef struct lua_State lua_State;
			typedef struct {
				lua_State *coro;
			} Foo;
		]]

		local stash = ffi.new('Foo')

		function pack(...)
			local m = {}
			for _, x in ipairs({...}) do
				table.insert(m, x)
			end
			return m
		end

		local co = coroutine.create(
			function()
				local got = pack(coro.yield(stash, "1.1", "1.2"))
				assert.same(got, {"2.1", "2.2"})

				got = pack(coro.yield(stash, "3.1", "3.2"))
				assert.same(got, {"4.1", "4.2"})

				return "5.1", "5.2"
			end)

		local got = pack(coroutine.resume(co))
		assert.same(got, {true, "1.1", "1.2"})

		got = pack(coro.resume(stash, "2.1", "2.2"))
		assert.same(got, {"3.1", "3.2"})

		got = pack(coro.resume(stash, "4.1", "4.2"))
		assert.same(got, {"5.1", "5.2"})
	end,
}
