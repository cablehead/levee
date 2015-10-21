return {
	test_core = function()
		local levee = require("levee")

		local h = levee.Hub()
		h:continue()

		local chan = h:channel()
		local recver = chan:bind()
		local sender = recver:create_sender()

		sender:send(1)
		sender:send(2)
		sender:send(3)

		-- normally these two halves would be running in different threads
		h:continue()

		assert.equal(recver:recv(), 1)
		assert.equal(recver:recv(), 2)
		assert.equal(recver:recv(), 3)
	end,

	test_connect = function()
		local levee = require("levee")

		local parent = {}
		parent.h = levee.Hub()
		parent.h:continue()
		parent.recver = parent.h:channel():bind()

		local child = {}
		child.h = levee.Hub()
		child.h:continue()
		child.sender = parent.recver:create_sender()

		child.recver = child.sender:connect(child.h:channel())
		parent.h:continue()
		parent.sender = parent.recver:recv()

		parent.sender:send(123)
		child.h:continue()
		assert.equal(child.recver:recv(), 123)

		child.sender:send(321)
		parent.h:continue()
		assert.equal(parent.recver:recv(), 321)
	end,
}
