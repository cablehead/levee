return {
	test_pipe = function()
		if true then return 'SKIP' end
		local levee = require("levee")

		levee.run(function(h)
			local sender, recver = unpack(h:pipe())

			assert.equal(sender.hub, h)
			assert.equal(recver.hub, h)

			-- test recv and then send
			h:spawn(function() assert.equal(sender:send("1"), true) end)
			local got = recver:recv()
			assert.equal(got, "1")

			-- test send and then recv
			local state
			h:spawn(function() state = recver:recv() end)
			assert.equal(sender:send("2"), true)
			h:pause()
			assert.equal(state, "2")
		end)
	end,

	test_pipe_close = function()
		if true then return 'SKIP' end
		local levee = require("levee")

		levee.run(function(h)
			-- test close sender and then recv
			local sender, recver = unpack(h:pipe())
			sender:close()
			assert.equal(recver:recv(), nil)

			-- test recv and then close sender
			local state = 'to set'
			local sender, recver = unpack(h:pipe())
			h:spawn(function() state = recver:recv() end)
			h:pause()
			sender:close()
			h:pause()
			assert.equal(state, nil)

			-- test close recver and then send
			local sender, recver = unpack(h:pipe())
			recver:close()
			assert.equal(sender:send("1"), nil)

			-- test send and then close recver
			local sender, recver = unpack(h:pipe())
			local state = 'to set'
			h:spawn(function() state = sender:send("1") end)
			h:pause()
			recver:close()
			h:pause()
			assert.equal(state, nil)
		end)
	end,

	test_switch = function()
		if true then return 'SKIP' end
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

	test_switch_close = function()
		if true then return 'SKIP' end
		local levee = require("levee")

		levee.run(function(h)
			-- test close sender and then recv
			local sender, recver = unpack(h:switch())
			sender:close()
			assert.equal(recver:recv(), nil)

			-- test recv and then close sender
			local state = 'to set'
			local sender, recver = unpack(h:switch())
			h:spawn(function() state = recver:recv() end)
			h:pause()
			sender:close()
			h:pause()
			assert.equal(state, nil)

			-- test close recver and then send
			local sender, recver = unpack(h:switch())
			recver:close()
			assert.equal(sender:send(true), nil)
		end)
	end,

	test_switch_clear_on_recv = function()
		if true then return 'SKIP' end
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
		if true then return 'SKIP' end
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
		if true then return 'SKIP' end
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
