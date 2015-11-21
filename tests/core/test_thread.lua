local levee = require("levee")


return {
	test_channel_core = function()
		local h = levee.Hub()
		h:continue()

		local chan = h.thread:channel()

		local recver = chan:bind()
		local sender = recver:create_sender()

		sender:send(1)
		sender:send(2)
		sender:send(3)

		-- normally these two halves would be running in different threads
		h:continue()

		assert.same({recver:recv()}, {nil, 1})
		assert.same({recver:recv()}, {nil, 2})
		assert.same({recver:recv()}, {nil, 3})
	end,

	test_channel_table = function()
		local h = levee.Hub()
		h:continue()

		local chan = h.thread:channel()

		local recver = chan:bind()
		local sender = recver:create_sender()

		sender:send({ name = "test", value = 123, nested = { 1, 2, 3 }})

		-- normally these two halves would be running in different threads
		h:continue()

		assert.same(
			{recver:recv()},
			{nil, { name = "test", value = 123, nested = { 1, 2, 3 }}})
	end,

	test_channel_connect = function()
		local parent = {}
		parent.h = levee.Hub()
		parent.h:continue()
		parent.recver = parent.h.thread:channel():bind()

		local child = {}
		child.h = levee.Hub()
		child.h:continue()
		child.sender = parent.recver:create_sender()

		child.recver = child.sender:connect(child.h.thread:channel())
		parent.h:continue()
		local err
		err, parent.sender = parent.recver:recv()

		parent.sender:send(123)
		child.h:continue()
		assert.same({child.recver:recv()}, {nil, 123})

		child.sender:send(321)
		parent.h:continue()
		assert.same({parent.recver:recv()}, {nil, 321})
	end,

	test_call = function()
		local h = levee.Hub()

		local function add(a, b)
			return nil, a + b
		end
		assert.same({h.thread:call(add, 3, 2):recv()}, {nil, 5})

		local function throw(n)
			local errors = require("levee.errors")
			return errors.get(n)
		end

		local err = h.thread:call(throw, 4):recv()
		assert.equal(err, levee.errors.get(4))
	end,

	test_spawn = function()
		local h = levee.Hub()

		local function f(h)
			local errors = require("levee.errors")

			local err, got = h.parent:recv()
			assert(not err)
			assert(got == 123)

			h.parent:send(321)
			h.parent:error(errors.get(1))
		end

		local child = h.thread:spawn(f)
		child:send(123)
		assert.same({child:recv()}, {nil, 321})
		assert.same({child:recv()}, {levee.errors.get(1)})
	end,
}
