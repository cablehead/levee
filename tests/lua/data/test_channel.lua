return {
	test_core = function()
		local levee = require("levee")

		local h = levee.Hub()

		local chan = h:channel()
		local recver = chan:bind()
		local sender = recver:create_sender()

		sender:send(1)
		sender:send(2)
		sender:send(3)

		-- normally these two halves would be running in different threads
		h:continue()
		h:continue()

		assert.equal(recver:recv(), 1)
		assert.equal(recver:recv(), 2)
		assert.equal(recver:recv(), 3)
	end,

	test_connect = function()
		local levee = require("levee")

		local h = levee.Hub()

		local parent = {}
		local child = {}

		parent.chan = h:channel()
		parent.recver = parent.chan:bind()

		child.chan = h:channel()
		child.sender = parent.recver:create_sender()
		child.recver = child.sender:connect(child.chan)

		h:continue()
		h:continue()

		parent.sender = parent.recver:recv()

		parent.sender:send(123)
		h:continue()
		assert.equal(child.recver:recv(), 123)

		child.sender:send(321)
		h:continue()
		assert.equal(parent.recver:recv(), 321)
	end,
}
