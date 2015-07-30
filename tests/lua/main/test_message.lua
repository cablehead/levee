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

	test_pipe_iter = function()
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

	test_pipe_close_recver = function()
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
		assert.equal(state, "done")
	end,

	test_queue = function()
		local h = require("levee").Hub()
		local q = h:queue()

		-- test send and then recv
		q:send("1")
		q:send("2")
		q:send("3")
		assert.equal(q:recv(), "1")
		assert.equal(q:recv(), "2")
		assert.equal(q:recv(), "3")

		-- test recv and then send
		local state
		h:spawn(function() state = q:recv() end)
		q:send("1")
		h:continue()
		assert.equal(state, "1")

		-- test close
		q:send("1")
		q:send("2")
		q:send("3")
		q:close()
		assert.equal(q:recv(), "1")
		assert.equal(q:recv(), "2")
		assert.equal(q:recv(), "3")
		assert.equal(q:recv(), nil)
	end,

	test_queue_size = function()
		local h = require("levee").Hub()

		local q = h:queue(3)

		h:spawn(function()
			for i = 1, 10 do q:send(i) end
			q:close()
		end)

		local check = 0
		for i in q do
			check = check + 1
			assert.equal(i, check)
		end
		assert.equal(check, 10)
	end,

	test_selector = function()
		local h = require("levee").Hub()

		local p1 = h:pipe()
		local p2 = h:pipe()

		local s = h:selector()

		-- send before redirect
		h:spawn(function() p1:send("0") end)

		p1:redirect(s)
		p2:redirect(s)

		assert.same({s:recv()}, {p1, "0"})

		-- send and then recv
		h:spawn(function() p1:send("1") end)
		assert.same({s:recv()}, {p1, "1"})

		-- recv and then send
		local check
		h:spawn(function() check = {s:recv()} end)
		p2:send("2")
		assert.same(check, {p2, "2"})

		-- 2x pending
		h:spawn(function() p2:send("2") end)
		h:spawn(function() p1:send("1") end)
		assert.same({s:recv()}, {p2, "2"})
		assert.same({s:recv()}, {p1, "1"})
	end,
}
