local levee = require("levee")


return {
	test_close_writer = function()
		local h = levee.Hub()

		local err, r, w = h.io:pipe()
		assert(not err)

		local err, n = w:write("foo")
		assert(not err)
		assert.equal(n, 3)

		local buf = levee.d.buffer(4096)
		local err, n = r:read(buf:tail())
		assert(not err)
		assert.equal(n, 3)
		buf:bump(n)
		assert.equal(buf:take(), "foo")

		w:close()
		local err = r:read(buf:tail())
		assert.equal(err, levee.errors.CLOSED)
		assert.same(h.registered, {})
	end,

	test_close_reader = function()
		local h = levee.Hub()

		local err, r, w = h.io:pipe()
		assert(not err)

		r:close()
		-- continue is required to flush the close
		h:continue()

		local err, n = w:write("foo")
		assert(err)
	end,

	test_eagain = function()
		local h = levee.Hub()

		local err, r, w = h.io:pipe()
		assert(not err)

		-- read eagain
		local buf = levee.d.buffer(100000)
		h:spawn(function() err, n = r:read(buf:tail()); buf:bump(n) end)
		local err, n = w:write("foo")
		assert(not err)
		assert.equal(n, 3)
		assert.equal(buf:take(3), "foo")

		-- write eagain
		local want = x(".", 100000)
		local check
		h:spawn(function() check = {w:write(want)} end)

		while #buf < 100000 do
			local err, n = r:read(buf:tail())
			assert(not err)
			buf:bump(n)
		end

		assert.same(check, {nil, 100000})
		assert.equal(buf:take(), want)
	end,

	test_timeout = function()
		local h = levee.Hub()
		local err, r, w = h.io:pipe(20)

		local buf = levee.d.buffer(4096)
		local got = r:read(buf:tail())
		assert.equal(got, levee.errors.TIMEOUT)
	end,

	test_last_read = function()
		local h = levee.Hub()

		local err, r, w = h.io:pipe()
		assert(not err)

		w:write("foo")
		w:close()

		local buf = levee.d.buffer(4096)
		local err, n = r:read(buf:tail())
		assert(not err)
		assert.equal(n, 3)
		buf:bump(n)
		assert.equal(buf:take(), "foo")

		local err, n = r:read(buf:tail())
		assert(err)
		assert.same(h.registered, {})
	end,

	test_readinto = function()
		local h = levee.Hub()

		local err, r, w = h.io:pipe()

		local buf = levee.d.buffer(4096)

		w:write("foo")
		local err, n = r:readinto(buf)
		assert(not err)
		assert.equal(n, 3)
		assert.equal(buf:take(), "foo")

		w:close()
		local err = r:readinto(buf)
		assert.equal(err, levee.errors.CLOSED)
		assert.same(h.registered, {})
	end,

	test_reads = function()
		local h = levee.Hub()

		local err, r, w = h.io:pipe()
		w:write("foo")
		assert.equal(r:reads(), "foo")
		w:close()
		assert.equal(r:reads(), nil)
		assert.same(h.registered, {})
	end,

	test_writev = function()
		local h = levee.Hub()

		local err, r, w = h.io:pipe()
		assert(not err)
		local iov = h.io.iovec(32)

		-- to prevent gc
		local keep = {}
		local want = {}
		for i = 1, 12 do
			local s = x(tostring(i), 10000+i)
			iov:write(s)
			table.insert(keep, s)
			table.insert(want, s)
		end
		want = table.concat(want)

		local err, total
		h:spawn(function()
			err, total = w:writev(iov.iov, iov.n)
			w:close()
		end)

		local got = {}
		while true do
			local s = r:reads(64*1024)
			if not s then break end
			table.insert(got, s)
		end
		got = table.concat(got)

		assert.equal(#want, #got)
		assert.equal(want, got)
		assert.equal(total, #got)
		assert(not err)
	end,

	test_iov = function()
		local h = levee.Hub()

		local err, r, w = h.io:pipe()

		local iov = w:iov()

		local want = {}

		h:spawn(function()
			for i = 1, 1000 do
				local s = x(tostring(i), i)
				table.insert(want, s)
				iov:send(s)
			end

			-- test if items are added to the queue while we are mid-write
			local s = x(".", 791532)
			table.insert(want, s)
			iov:send(s)
			h:continue()
			table.insert(want, "...")
			iov:send(".")
			iov:send(".")
			iov:send(".")

			iov.empty:recv()
			w:close()
			want = table.concat(want)
		end)

		local buf = levee.d.buffer(4096)
		while true do
			local err, n = r:readinto(buf)
			if err then break end
		end

		assert.equal(#want, #buf)
		assert.equal(want, buf:take())
	end,

	test_stream = function()
		local h = levee.Hub()
		local r, w = h.io:pipe()
		local s = r:stream()

		w:write("foo")
		s:readin()
		w:write("foo")
		local buf, n = s:value()
		assert.equal(n, 3)

		s:readin()
		local buf, n = s:value()
		assert.equal(n, 6)

		w:close()
		assert(s:readin(20) < 0)
	end,

	test_chunk = function()
		local h = levee.Hub()
		local r, w = h.io:pipe()
		local s = r:stream()

		local c = s:chunk(10)
		assert.equal(#c, 10)

		h:spawn(function() w:write(x(".", 15)) end)
		assert.equal(c:tostring(), "..........")
		assert.equal(c.done:recv(), nil)

		local c = s:chunk(10)
		w:close()
		assert.equal(c:tostring(), -1)
	end,
}
