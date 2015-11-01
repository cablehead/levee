local levee = require("levee")


return {
	test_pipe_recv_then_send = function()
		local h = levee.Hub()

		local sender, recver = h:pipe()

		local sent = false

		h:spawn_later(10, function()
			local i = 0
			while true do
				i = i + 1
				sent = true
				local err = sender:send(i)
				assert(not err)
				sent = false
				if i == 2 then break end
			end
			sender:close()
		end)

		assert(not sent)
		local err, value = recver:recv()
		assert(not err)
		assert.equal(value, 1)
		assert(sent)

		local err, value = recver:recv()
		assert(not err)
		assert.equal(value, 2)
		assert(sent)

		local err, value = recver:recv()
		assert.equal(err, levee.errors.CLOSED)

		assert.equal(sender:send(1), levee.errors.CLOSED)
		assert.equal(recver:recv(), levee.errors.CLOSED)
		assert.equal(sender:close(), levee.errors.CLOSED)
		assert.equal(recver:close(), levee.errors.CLOSED)
	end,

	test_pipe_send_then_recv = function()
		local h = levee.Hub()

		local sender, recver = h:pipe()

		local sent = false
		local state

		h:spawn(function()
			local err
			local i = 0
			while true do
				i = i + 1
				sent = i
				err = sender:send(i)
				if err then break end
			end
			state = err
		end)

		assert.equal(sent, 1)
		local err, value = recver:recv()
		assert(not err)
		assert.equal(value, 1)

		assert.equal(sent, 1)
		h:continue()
		assert.equal(sent, 2)
		local err, value = recver:recv()
		assert(not err)
		assert.equal(value, 2)

		h:continue()
		assert.equal(sent, 3)
		recver:close()
		assert.equal(state, nil)
		h:continue()
		assert.equal(state, levee.errors.CLOSED)
	end,

	test_pipe_timeout = function()
		local h = levee.Hub()

		local sender, recver = h:pipe()

		assert.equal(recver:recv(10), levee.errors.TIMEOUT)
		assert.equal(#h.scheduled, 0)

		h:spawn_later(10, function() sender:send("foo") end)
		assert.same({recver:recv(20)}, {nil, "foo"})
		assert.equal(#h.scheduled, 0)

		h:spawn(function() sender:send("foo") end)
		assert.same({recver:recv(0)}, {nil, "foo"})
		assert.equal(#h.scheduled, 0)

		assert.equal(recver:recv(0), levee.errors.TIMEOUT)
		assert.equal(#h.scheduled, 0)
	end,

	test_pipe_iter = function()
		local h = levee.Hub()

		local sender, recver = h:pipe()

		h:spawn(
			function()
				for i = 1, 3 do
					sender:send(i)
				end
				sender:close()
			end)

		local got = {}
		for i in recver do table.insert(got, i) end
		assert.same(got, {1, 2, 3})
	end,

	test_pipe_redirect = function()
		local h = levee.Hub()

		local producer = (function()
			local sender, recver = h:pipe()
			h:spawn(function()
				local i = 0
				while true do
					i = i + 1
					if sender:send(i) then return end
					if i == 3 then break end
				end
				sender:close()
			end)
			return recver
		end)()

		local check = {}
		local consumer = (function()
			local sender, recver = h:pipe()
			h:spawn(function()
				for i in recver do
					table.insert(check, i)
				end
			end)
			return recver
		end)()

		producer:redirect(consumer)
		assert.same(check, {})
		h:continue()
		assert.same(check, {1})
		h:continue()
		assert.same(check, {1, 2})
		h:continue()
		assert.same(check, {1, 2, 3})
		h:continue()
		assert.same(check, {1, 2, 3})
	end,

	test_value = function()
		local h = levee.Hub()

		local sender, recver = h:value(1)
		assert.same({recver:recv()}, {nil, 1})
		assert.same({recver:recv()}, {nil, 1})

		sender:send()
		assert.same({recver:recv(10)}, {levee.errors.TIMEOUT})

		h:spawn_later(10, function() sender:send(2) end)
		assert.same({recver:recv(20)}, {nil, 2})

		sender:send(3)
		sender:send(4)
		assert.same({recver:recv()}, {nil, 4})
		assert.same({recver:recv()}, {nil, 4})
	end,

	test_gate = function()
		local h = levee.Hub()
		local g = h:gate()

		-- test send and then recv
		local got
		h:spawn_later(10, function() got = g:recv() end)

		local sent
		h:spawn(function()
			for i = 1, 5 do
				sent = i
				if not g:send(i) then break end
			end
			sent = 20
		end)

		h:sleep(20)
		assert.equal(sent, 1)
		assert.equal(got, 1)
		h:continue()
		assert.equal(sent, 1)
		assert.equal(got, 1)

		-- test recv and then send
		h:spawn(function() got = g:recv() end)
		h:continue()
		assert.equal(sent, 2)
		assert.equal(got, 1)
		h:continue()
		assert.equal(sent, 2)
		assert.equal(got, 2)
		h:continue()
		assert.equal(sent, 2)
		assert.equal(got, 2)

		got = g:recv()
		assert.equal(sent, 3)
		assert.equal(got, 3)
		h:continue()
		assert.equal(sent, 3)
		assert.equal(got, 3)

		-- close
		g:close()
		assert.equal(g:recv(), nil)
		assert.equal(sent, 20)
	end,

	test_queue = function()
		local h = levee.Hub()
		local q = h:queue()

		-- test send and then recv
		assert.equal(q.empty:recv(), true)
		q:send("1")
		assert.equal(q.empty:recv(10), levee.TIMEOUT)
		q:send("2")
		q:send("3")
		assert.equal(q:recv(), "1")
		assert.equal(q:recv(), "2")
		assert.equal(q.empty:recv(10), levee.TIMEOUT)
		assert.equal(q:recv(), "3")
		assert.equal(q.empty:recv(), true)

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
		local h = levee.Hub()

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

	test_stalk_send_then_recv = function()
		local h = levee.Hub()
		local q = h:stalk(3)

		local sent
		h:spawn(function()
			for i = 1, 10 do
				sent = i
				q:send(i)
			end
			sent = 20
		end)

		assert.equal(sent, 4)
		assert.equal(q:recv(), true)
		h:continue()
		-- recv-ing doesn't remove items from the queue
		assert.equal(sent, 4)

		local check = {}
		for i in q:iter() do table.insert(check, i) end
		assert.same(check, {1, 2, 3})

		q:remove(2)
		h:continue()
		local check = {}
		assert.equal(q:recv(), true)
		for i in q:iter() do table.insert(check, i) end
		assert.same(check, {3, 4, 5})

		q:remove(#q)
		h:continue()
		local check = {}
		for i in q:iter() do table.insert(check, i) end
		assert.same(check, {6, 7, 8})

		q:remove(#q)
		h:continue()
		local check = {}
		for i in q:iter() do table.insert(check, i) end
		assert.same(check, {9, 10})

		assert.equal(q.empty:recv(10), levee.TIMEOUT)
		q:remove(#q)
		assert.equal(q.empty:recv(), true)

		assert.equal(sent, 20)
	end,

	test_stalk_recv_then_send = function()
		local h = levee.Hub()
		local q = h:stalk(3)

		local check = {}
		h:spawn(function()
			while true do
				if not q:recv() then break end
				for i in q:iter() do
					table.insert(check, i)
				end
				q:remove(#q)
			end
			table.insert(check, 20)
		end)

		q:send(1)
		h:continue()
		assert.same(check, {1})

		q:send(2)
		q:send(3)
		q:send(4)
		assert.same(check, {1})

		q:send(5)
		assert.same(check, {1, 2, 3, 4})
		q:send(6)
		q:send(7)
		h:continue()
		assert.same(check, {1, 2, 3, 4, 5, 6, 7})

		q:send(8)
		q:send(9)
		q:close()
		h:continue()
		assert.same(check, {1, 2, 3, 4, 5, 6, 7, 8, 9, 20})
	end,

	test_selector = function()
		local h = levee.Hub()

		local s1, r1 = h:pipe()
		local s2, r2 = h:pipe()

		local s = h:selector()

		-- send before redirect
		h:spawn(function() s1:send("0") end)

		r1:redirect(s)
		r2:redirect(s)

		assert.same({s:recv()}, {nil, s1, "0"})

		-- send and then recv
		h:spawn(function() s1:send("1") end)
		assert.same({s:recv()}, {nil, s1, "1"})

		-- recv and then send
		local check
		h:spawn(function() check = {s:recv()} end)
		s2:send("2")
		assert.same(check, {nil, s2, "2"})

		-- 2x pending
		h:spawn(function() s2:send("2") end)
		h:spawn(function() s1:send("1") end)
		assert.same({s:recv()}, {nil, s2, "2"})
		assert.same({s:recv()}, {nil, s1, "1"})

		-- test timeout
		assert.equal(s:recv(10), levee.errors.TIMEOUT)
		h:spawn_later(10, function() s1:send("1") end)
		assert.same({s:recv(20)}, {nil, s1, "1"})

		-- test sender close
		h:spawn(function() s1:close() end)
		assert.same({s:recv()}, {levee.errors.CLOSED, s1})
	end,
}
