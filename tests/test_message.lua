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
			assert.equal(got, "1")

			-- test send and then recv
			local done = h:pipe()
			h:spawn(
				function()
					local got = recver:recv()
					assert.equal(got, "2")
					done.sender:send(true)
				end)
			sender:send("2")
			done.recver:recv()
		end)
	end,

	test_switch = function()
		local levee = require("levee")

		levee.run(function(h)
			local sender, recver = unpack(h:switch())

			local state = 0

			h:spawn(function()
				while true do
					local got = recver:recv()
					assert.equal(got, true)
					state = state + 1
					h:pause()
				end
			end)

			-- switch closed
			h:pause()
			assert.equal(state, 0)

			-- open switch
			sender:send(true)
			h:pause()
			assert.equal(state, 1)

			-- switch stays open
			h:pause()
			assert.equal(state, 2)

			-- close switch
			sender:send(false)
			h:pause()
			assert.equal(state, 2)
		end)
	end,

	test_switch_clear_on_recv = function()
		local levee = require("levee")

		levee.run(function(h)
			local sender, recver = unpack(h:switch(true))

			local state = 0

			h:spawn(function()
				while true do
					local got = recver:recv()
					assert.equal(got, true)
					state = state + 1
					h:pause()
				end
			end)

			-- switch closed
			h:pause()
			assert.equal(state, 0)

			-- open switch
			sender:send(true)
			h:pause()
			assert.equal(state, 1)

			-- switch should have closed
			h:pause()
			assert.equal(state, 1)
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
		local task = require("levee.task")

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
				local got = pack(task.yield(stash, "1.1", "1.2"))
				assert.same(got, {"2.1", "2.2"})

				got = pack(task.yield(stash, "3.1", "3.2"))
				assert.same(got, {"4.1", "4.2"})

				return "5.1", "5.2"
			end)

		local got = pack(coroutine.resume(co))
		assert.same(got, {true, "1.1", "1.2"})

		got = pack(task.resume(stash, "2.1", "2.2"))
		assert.same(got, {true, "3.1", "3.2"})

		got = pack(task.resume(stash, "4.1", "4.2"))
		assert.same(got, {true, "5.1", "5.2"})
	end,
}
