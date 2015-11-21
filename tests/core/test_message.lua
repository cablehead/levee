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

	test_pipe_pass = function()
		local h = levee.Hub()

		local sender, recver = h:pipe()

		local err = levee.errors.get(1)

		h:spawn(function() sender:pass((function() return err end)()) end)
		assert.same({recver:recv()}, {err})

		h:spawn(function() sender:pass((function() return nil, 3 end)()) end)
		assert.same({recver:recv()}, {nil, 3})

		h:spawn(function() sender:pass((function() return err end)()) end)
		assert.same({recver:recv()}, {err})
	end,

	test_pipe_error = function()
		local h = levee.Hub()
		local sender, recver = h:pipe()
		local err = levee.errors.get(1)
		h:spawn(function() sender:error(err) end)
		assert.equal(recver:recv(), err)
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

		local sender, recver = h:gate()

		-- test send and then recv
		local sent
		local got

		h:spawn_later(10, function() got = {recver:recv()} end)

		h:spawn(function()
			for i = 1, 5 do
				sent = i
				if sender:send(i) then break end
			end
			sent = 20
		end)

		assert.equal(sent, 1)
		assert.equal(got, nil)

		h:sleep(20)
		assert.equal(sent, 1)
		assert.same(got, {nil, 1})

		h:continue()
		-- sender can't make progress
		assert.equal(sent, 1)
		assert.same(got, {nil, 1})

		-- test recv and then send
		h:spawn(function() got = {recver:recv()} end)
		h:continue()
		assert.equal(sent, 2)
		h:continue()
		assert.same(got, {nil, 2})

		got = {recver:recv()}
		assert.equal(sent, 3)
		assert.same(got, {nil, 3})
		h:continue()
		assert.equal(sent, 3)
		assert.same(got, {nil, 3})

		recver:close()
		h:continue()
	end,

	test_queue_core = function()
		local h = levee.Hub()

		local sender, recver = h:queue()

		-- test timeout
		assert.same({recver:recv(10)}, {levee.errors.TIMEOUT})

		-- test send and then recv
		assert.same({recver.empty:recv()}, {nil, true})
		sender:send("1")
		assert.same({recver.empty:recv(10)}, {levee.errors.TIMEOUT})
		sender:send("2")
		sender:send("3")
		assert.same({recver:recv()}, {nil, "1"})
		assert.same({recver:recv()}, {nil, "2"})
		assert.same({recver.empty:recv(10)}, {levee.errors.TIMEOUT})
		assert.same({recver:recv()}, {nil, "3"})
		assert.same({recver.empty:recv()}, {nil, true})

		-- test recv and then send
		local state
		h:spawn(function() state = {recver:recv()} end)
		sender:send("1")
		h:continue()
		assert.same(state, {nil, "1"})

		-- test close
		sender:send("1")
		sender:send("2")
		sender:send("3")
		sender:close()
		assert.same({recver:recv()}, {nil, "1"})
		assert.same({recver:recv()}, {nil, "2"})
		assert.same({recver:recv()}, {nil, "3"})
		assert.same({recver:recv()}, {levee.errors.CLOSED})
	end,

	test_queue_iter = function()
		local h = levee.Hub()

		local sender, recver = h:queue()

		for i = 1, 3 do sender:send(i) end
		sender:close()

		local got = {}
		for i in recver do table.insert(got, i) end
		assert.same(got, {1, 2, 3})
	end,

	test_queue_close = function()
		local h = levee.Hub()

		local sender, recver = h:queue()

		local glob = 3
		local check
		recver.on_close = function() check = glob end

		recver:close()
		assert.equal(check, 3)
		assert.equal(sender:send(1), levee.errors.CLOSED)
		assert.equal(recver:recv(), levee.errors.CLOSED)
	end,

	test_queue_size = function()
		local h = levee.Hub()

		local sender, recver = h:queue(2)

		local check
		h:spawn(function()
			for i = 1, 5 do
				check = i
				sender:send(i)
			end
			sender:close()
		end)

		assert.equal(check, 3)
		h:continue()
		assert.equal(check, 3)

		assert.same({recver:recv()}, {nil, 1})
		h:continue()
		assert.equal(check, 4)

		assert.same({recver:recv()}, {nil, 2})
		h:continue()
		assert.equal(check, 5)

		assert.same({recver:recv()}, {nil, 3})
		h:continue()
		assert.equal(check, 5)

		assert.same({recver:recv()}, {nil, 4})
		assert.same({recver:recv()}, {nil, 5})
		assert.same({recver:recv()}, {levee.errors.CLOSED})
	end,

	test_stalk_send_then_recv = function()
		local h = levee.Hub()

		local sender, recver = h:stalk(3)

		assert.same({recver:recv(10)}, {levee.errors.TIMEOUT})

		local sent
		h:spawn(function()
			for i = 1, 10 do
				sent = i
				sender:send(i)
			end
			sender:close()
		end)

		assert.equal(sent, 4)
		assert.same({recver:recv(10)}, {nil, true})
		h:continue()
		-- recv-ing doesn't remove items from the queue
		assert.equal(sent, 4)

		local check = {}
		for i in recver:iter() do table.insert(check, i) end
		assert.same(check, {1, 2, 3})

		recver:remove(2)
		h:continue()
		local check = {}
		assert.same({recver:recv()}, {nil, true})
		for i in recver:iter() do table.insert(check, i) end
		assert.same(check, {3, 4, 5})

		recver:remove(#recver)
		h:continue()
		local check = {}
		for i in recver:iter() do table.insert(check, i) end
		assert.same(check, {6, 7, 8})

		recver:remove(#recver)
		h:continue()
		local check = {}
		for i in recver:iter() do table.insert(check, i) end
		assert.same(check, {9, 10})

		assert.same({recver.empty:recv(10)}, {levee.errors.TIMEOUT})
		recver:remove(#recver)
		assert.same({recver.empty:recv(10)}, {nil, true})
		assert.same({recver:recv()}, {levee.errors.CLOSED})
	end,

	test_stalk_recv_then_send = function()
		local h = levee.Hub()

		local sender, recver = h:stalk(3)

		local check = {}
		h:spawn(function()
			while true do
				local err, ok = recver:recv()
				if err then break end
				for i in recver:iter() do
					table.insert(check, i)
				end
				recver:remove(#recver)
			end
			table.insert(check, 20)
		end)

		sender:send(1)
		h:continue()
		assert.same(check, {1})

		sender:send(2)
		sender:send(3)
		sender:send(4)
		assert.same(check, {1})

		sender:send(5)
		assert.same(check, {1, 2, 3, 4})
		sender:send(6)
		sender:send(7)
		h:continue()
		assert.same(check, {1, 2, 3, 4, 5, 6, 7})

		sender:send(8)
		sender:send(9)
		sender:close()
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

		assert.same({s:recv()}, {nil, r1, "0"})

		-- send and then recv
		h:spawn(function() s1:send("1") end)
		assert.same({s:recv()}, {nil, r1, "1"})

		-- recv and then send
		local check
		h:spawn(function() check = {s:recv()} end)
		s2:send("2")
		assert.same(check, {nil, r2, "2"})

		-- 2x pending
		h:spawn(function() s2:send("2") end)
		h:spawn(function() s1:send("1") end)
		assert.same({s:recv()}, {nil, r2, "2"})
		assert.same({s:recv()}, {nil, r1, "1"})

		-- test timeout
		assert.equal(s:recv(10), levee.errors.TIMEOUT)
		h:spawn_later(10, function() s1:send("1") end)
		assert.same({s:recv(20)}, {nil, r1, "1"})

		-- test sender close
		h:spawn(function() s1:close() end)
		assert.same({s:recv()}, {levee.errors.CLOSED, r1})
	end,

	test_dealer = function()
		local h = levee.Hub()

		local sender, recver = h:dealer()

		assert.same({recver:recv(20)}, {levee.errors.TIMEOUT})

		local check = {}
		local function recv(s)
			local err, value = recver:recv()
			table.insert(check, s)
			table.insert(check, {err, value})
		end

		h:spawn(function() recv("r1") end)
		h:spawn(function() recv("r2") end)
		h:spawn(function() recv("r3") end)

		sender:send(3)
		assert.same(check, {"r1", {nil, 3}})
		check = {}

		sender:send(2)
		assert.same(check, {"r2", {nil, 2}})
		check = {}

		sender:send(1)
		assert.same(check, {"r3", {nil, 1}})
		check = {}

		h:spawn(function() recv("r1") end)
		h:spawn(function() recv("r2") end)
		h:spawn(function() recv("r3") end)

		sender:close()
		assert.same(check, {
			"r1", {levee.errors.CLOSED},
			"r2", {levee.errors.CLOSED},
			"r3", {levee.errors.CLOSED}, })
	end,

	test_pool = function()
		local h = levee.Hub()

		local pool = h:pool(function() return "foo" end, 3)

		assert.same({pool:recv()}, {nil, "foo"})
		assert.same({pool:recv()}, {nil, "foo"})
		assert.same({pool:recv()}, {nil, "foo"})

		assert.same({pool:recv(20)}, {levee.errors.TIMEOUT})
		assert.same({pool:recv(20)}, {levee.errors.TIMEOUT})

		pool:send("foo")
		assert.same({pool:recv()}, {nil, "foo"})

		pool:send("foo")
		assert.same(
			{pool:run(function(s1, s2) return nil, s1 .. s2 end, "bar")},
			{nil, "foobar"})
	end,
}
