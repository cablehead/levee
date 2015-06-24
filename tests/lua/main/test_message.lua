return {
	test_pipe = function()
		local h = require("levee").Hub()
		local p = h:pipe()

		-- recv and then send
		local sent = false
		h:spawn_later(10, function() sent = true; p:send("1") end)
		assert(not sent)
		assert.equal(p:recv(), "1")

		-- send and then recv
		local sent = false
		h:spawn(function() sent = true; p:send("2") end)
		assert(sent)
		assert.equal(p:recv(), "2")
	end,

	test_iter = function()
		local h = require("levee").Hub()
		local p = h:pipe()

		h:spawn(
			function()
				for i = 1, 3 do
					p:send(i)
				end
				p:close()
			end)

		local want = 1
		for i in p do
			assert.equal(want, i)
			want = want + 1
		end
	end,

	test_close_recver = function()
		local h = require("levee").Hub()
		local p = h:pipe()

		local state
		h:spawn(
			function()
				while true do
					local ok = p:send("foo")
					if not ok then break end
				end
				state = "done"
			end)

		assert.equal(p:recv(), "foo")
		assert.equal(p:recv(), "foo")
		assert.equal(p:recv(), "foo")

		p:close()
		-- Should this continue still be needed?
		h:continue()
		assert.equal(state, "done")
	end,
}
