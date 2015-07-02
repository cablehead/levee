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
}
