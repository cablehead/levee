return {
	test_pipe = function()
		local levee = require("levee")

		levee.run(function(h)
			local sender, recver = unpack(h:pipe())

			assert.equal(sender.hub, h)
			assert.equal(recver.hub, h)

			-- test recv and then send
			h:spawn(function() sender:send("1") end)
			local got = recver:recv()
			assert(got == "1")

			-- test send and then recv
			local done = h:pipe()
			h:spawn(
				function()
					local got = recver:recv()
					assert(got == "2")
					done.sender:send(true)
				end)
			sender:send("2")
			done.recver:recv()
		end)
	end,

	test_gc = function()
		local ffi = require("ffi")

		local message = require("levee.message")

		local p = message.Pipe({id = 1})

		collectgarbage("collect")
		assert(p.sender.other ~= ffi.NULL)
		assert(p.recver.other ~= ffi.NULL)

		local sender, recver = unpack(p)

		p = nil
		collectgarbage("collect")
		assert(sender.other ~= ffi.NULL)
		assert(recver.other ~= ffi.NULL)

		recver = nil
		collectgarbage("collect")
		assert(sender.other, ffi.NULL)
		assert(sender.closed)

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
		assert.same(got, {true, "3.1", "3.2"})

		got = pack(coro.resume(stash, "4.1", "4.2"))
		assert.same(got, {true, "5.1", "5.2"})
	end,
}
