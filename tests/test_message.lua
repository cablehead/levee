return {
	test_pipe = function()
		local levee = require("levee")

		levee.run(function(h)
			local p = h:pipe()

			if true then return end

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

	test_gc = function()
		local ffi = require("ffi")

		local message = require("levee.message")

		local p = message.Pipe()

		collectgarbage("collect")
		assert.equal(p.sender, p.sender.other.other)
		assert.equal(p.recver, p.recver.other.other)

		local sender, recver = unpack(p)

		p = nil
		collectgarbage("collect")
		assert.equal(sender, sender.other.other)
		assert.equal(recver, recver.other.other)

		recver = nil
		collectgarbage("collect")
		assert(sender.other, ffi.NULL)

		sender = nil
		collectgarbage("collect")
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
