local ffi = require('ffi')
local C = ffi.C

local levee = require("levee")


return {
	test_close_writer = function()
		local h = levee.Hub()

		local r, w = h.io:pipe()

		local err, n = w:write("foo")
		assert(not err)
		assert.equal(n, 3)

		local buf = levee.d.Buffer(4096)
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

		local r, w = h.io:pipe()

		r:close()
		-- continue is required to flush the close
		h:continue()

		local err, n = w:write("foo")
		assert(err)
	end,

	test_eagain = function()
		local h = levee.Hub()

		local r, w = h.io:pipe()

		-- read eagain
		local buf = levee.d.Buffer(100000)
		h:spawn(function() err, n = r:read(buf:tail()); buf:bump(n) end)
		local err, n = w:write("foo")
		assert(not err)
		assert.equal(n, 3)
		assert.equal(buf:take(3), "foo")

		-- write eagain
		local want = ("."):rep(100000)
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
		local r, w = h.io:pipe(20)

		local buf = levee.d.Buffer(4096)
		local got = r:read(buf:tail())
		assert.equal(got, levee.errors.TIMEOUT)
	end,

	test_last_read = function()
		local h = levee.Hub()

		local r, w = h.io:pipe()

		w:write("foo")
		w:close()

		local buf = levee.d.Buffer(4096)
		local err, n = r:read(buf:tail())
		assert(not err)
		assert.equal(n, 3)
		buf:bump(n)
		assert.equal(buf:take(), "foo")

		local err, n = r:read(buf:tail())
		assert(err)
		assert.same(h.registered, {})
	end,

	test_readn = function()
		local h = levee.Hub()
		local r, w = h.io:pipe()
		local buf = levee.d.Buffer(4096)

		-- nil len
		local check
		h:spawn(function()
			local err, n = r:readn(buf:tail(), 6)
			assert(not err)
			buf:bump(n)
			check = buf:take()
		end)

		assert(not check)
		w:write("foo")
		assert(not check)
		w:write("bar123")
		assert.equal(check, "foobar")
		assert.equal(r:reads(), "123")

		-- non nil len
		local check
		h:spawn(function()
			local err, n = r:readn(buf:tail(), 6, 8)
			assert(not err)
			buf:bump(n)
			check = buf:take()
		end)

		assert(not check)
		w:write("foo")
		assert(not check)
		w:write("bar123")
		assert.equal(check, "foobar12")
		assert.equal(r:reads(), "3")
	end,

	test_readinto = function()
		local h = levee.Hub()
		local r, w = h.io:pipe()
		local buf = levee.d.Buffer(4096)

		-- nil n
		w:write("foo")
		local err = r:readinto(buf)
		assert(not err)
		assert.equal(buf:take(), "foo")

		-- non nil n
		w:write("foo")
		h:spawn(function() r:readinto(buf, 6) end)
		assert.equal(#buf, 0)
		w:write("bar123")
		assert.equal(#buf, 9)

		w:close()
		local err = r:readinto(buf)
		assert.equal(err, levee.errors.CLOSED)
		assert.same(h.registered, {})
	end,

	test_reads = function()
		local h = levee.Hub()

		local r, w = h.io:pipe()
		w:write("foo")
		assert.equal(r:reads(), "foo")
		w:close()
		assert.equal(r:reads(), nil)
		assert.same(h.registered, {})
	end,

	test_writev = function()
		local h = levee.Hub()

		local r, w = h.io:pipe()
		local iov = h.io.iovec(32)

		-- to prevent gc
		local keep = {}
		local want = {}
		for i = 1, 12 do
			local s = tostring(i):rep(10000+i)
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

		local r, w = h.io:pipe()
		local err, iov = w:iov()

		local want = {}

		h:spawn(function()
			for i = 1, 1000 do
				local s = tostring(i):rep(i)
				table.insert(want, s)
				iov:send(s)
			end

			-- test if items are added to the queue while we are mid-write
			local s = ("."):rep(791532)
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

		local buf = levee.d.Buffer(4096)
		while true do
			local err = r:readinto(buf)
			if err then break end
		end

		assert.equal(#want, #buf)
		assert.equal(want, buf:take())
	end,

	test_send = function()
		local h = levee.Hub()

		local r, w = h.io:pipe()
		w:send("1", "2", "3", "4", "5", "6", "7", "8", "9", "0")
		assert.equal(r:reads(10), "1234567890")

		r:close()
		w:send("1")
		h:continue()

		local err = w:send("1", "2", "3", "4", "5", "6", "7", "8", "9", "0")
		assert(err)
	end,

	test_open = function()
		local h = levee.Hub()

		local tmp = os.tmpname()

		local err, w = h.io:open(tmp, C.O_WRONLY)
		w:write('{"foo":"bar"}')
		w:close()

		local err, r = h.io:open(tmp, C.O_RDONLY)
		local s = r:stream()
		local err, value = s:json()
		assert.same(value, {foo = "bar"})
		r:close()

		os.remove(tmp)
		assert.same(h.registered, {})
	end,

	test_stream_core = function()
		local h = levee.Hub()

		local r, w = h.io:pipe()
		local s = r:stream()

		w:write("foo")
		s:readin()
		assert.equal(#s.buf, 3)

		w:write("foo")
		s:readin()
		assert.equal(#s.buf, 6)

		h:spawn(function() s:readin(9) end)
		w:write("fo")
		assert.equal(#s.buf, 6)
		w:write("o")
		assert.equal(#s.buf, 9)

		w:write("o")
		assert.equal(#s.buf, 9)

		assert.equal(s:trim(), 9)
		w:close()
		s:readin(1)
		assert.equal(s:take(1), 'o')
		assert.same({s:readin(1)}, {levee.errors.CLOSED})
		assert.equal(s:take(1), nil)
	end,

	test_stream_read = function()
		local h = levee.Hub()

		local r, w = h.io:pipe()

		local s = r:stream()
		local buf = levee.d.Buffer(4096)

		-- read buffered
		w:write(("."):rep(10))
		s:readin()
		w:write(("."):rep(5))
		assert.same({s:read(buf:tail(), 20)}, {nil, 10})
		buf:bump(10)
		assert.equal(buf:take(), ("."):rep(10))

		-- read more than available
		assert.same({s:read(buf:tail(), 5)}, {nil, 5})
		buf:bump(5)
		assert.equal(buf:take(), ("."):rep(5))

		-- read less than available
		w:write(("."):rep(20))
		assert.same({s:read(buf:tail(), 10)}, {nil, 10})
		buf:bump(10)
		assert.equal(buf:take(), ("."):rep(10))

		-- check remainder is still available
		s:readin()
		assert.equal(s:take(), ("."):rep(10))
	end,

	test_stream_readn = function()
		local h = levee.Hub()

		local r, w = h.io:pipe()

		local s = r:stream()
		local buf = levee.d.Buffer(4096)

		w:write(("."):rep(10))
		s:readin()
		w:write(("."):rep(5))

		local check
		h:spawn(function() check = {s:readn(buf:tail(), 20)} end)
		assert.equal(check, nil)

		w:write(("."):rep(10))
		assert.same(check, {nil, 20})
		buf:bump(20)
		assert.equal(buf:take(), ("."):rep(20))

		s:readin()
		assert.equal(s:take(), ("."):rep(5))
	end,

	test_stream_readinto = function()
		local h = levee.Hub()

		local r, w = h.io:pipe()

		local s = r:stream()
		local buf = levee.d.Buffer(4096)

		w:write(("."):rep(10))
		s:readin()
		w:write(("."):rep(20))

		s:readinto(buf, 20)
		assert.equal(buf:take(), ("."):rep(20))

		s:readin()
		assert.equal(s:take(), ("."):rep(10))
	end,

	test_chunk_core = function()
		local h = levee.Hub()

		local r, w = h.io:pipe()
		local s = r:stream()

		local c = s:chunk(10)
		assert.equal(#c, 10)

		h:spawn(function() w:write(("."):rep(15)) end)
		assert.equal(c:tostring(), "..........")
		assert.equal(c.done:recv(), levee.errors.CLOSED)

		local c = s:chunk(10)
		w:close()
		assert.equal(c:tostring(), nil)
	end,

	test_chunk_tobuffer = function()
		local h = levee.Hub()

		local r, w = h.io:pipe()

		local s = r:stream()
		w:write(("."):rep(10))
		s:readin()
		w:write(("."):rep(20))

		local c = s:chunk(20)
		local err, buf = c:tobuffer()
		assert.equal(buf:take(), ("."):rep(20))
		c.done:recv()
		s:readin(1)
		assert.equal(s:take(), ("."):rep(10))
	end,

	test_chunk_splice = function()
		local h = levee.Hub()

		local r, w = h.io:pipe()
		local r2, w2 = h.io:pipe()

		local s = r:stream()
		w:write(("."):rep(10))
		s:readin()
		w:write(("."):rep(20))

		local c = s:chunk(20)
		assert.same({c:splice(w2)}, {nil, 20})
		c.done:recv()
		assert.equal(r2:reads(), ("."):rep(20))
		assert.equal(s:take(), ("."):rep(10))
	end,

	test_chunk_splice_big = function()
		local h = levee.Hub()

		local r, w = h.io:pipe()
		local r2, w2 = h.io:pipe()

		local pre = ("."):rep(10)
		local val = ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"):rep(512)
		local crc = C.sp_crc32c(0ULL, pre, #pre)
		crc = C.sp_crc32c(crc, val, #val - 10)

		local s = r:stream()
		w:write(pre)
		s:readin()
		h:spawn(function() w:write(val) end)

		local c = s:chunk(64*512)
		assert.same({c:splice(w2)}, {nil, 64*512})
		c.done:recv()

		local buf = levee.d.Buffer()
		r2:stream():readinto(buf, 64*512)
		assert.equal(C.sp_crc32c(0ULL, buf:value()), crc)
		assert.equal(s:take(10), "23456789+/")
	end,

	test_chunk_discard = function()
		local h = levee.Hub()

		local r, w = h.io:pipe()

		local s = r:stream()
		w:write(("."):rep(10))
		s:readin()
		w:write(("."):rep(20))

		local c = s:chunk(20)
		assert.same({c:discard()}, {nil, 20})
		c.done:recv()
		assert.equal(s:take(), ("."):rep(10))
	end,

	test_chunk_json = function()
		local h = levee.Hub()
		local r, w = h.io:pipe()

		local json = '{"foo": "bar"}'
		w:write(json)

		local s = r:stream()
		local c = s:chunk(#json)
		local err, value = c:json()

		assert.same(value, {foo = "bar"})
		c.done:recv()
	end,

	test_shared_ev = function()
		local h = levee.Hub()
		local io = require("levee.core.io")(h)
		local r, w = h.io:pipe()

		local Teed_R_mt = {}
		Teed_R_mt.__index = Teed_R_mt

		function Teed_R_mt:clone()
			local c = setmetatable({}, io.R_mt)
			c.hub = self.r.hub
			c.no = self.r.no
			c.timeout = self.r.timeout
			local sender, recver = h:flag()
			self.evs[sender] = 1
			c.ev = recver
			return c
		end

		local function Teed_R(r)
			local self = setmetatable({}, Teed_R_mt)
			self.r = r
			self.evs = {}

			h:spawn(function()
				while true do
					local err, sender, value = self.r.r_ev:recv()
					for ev, v in pairs(self.evs) do
						ev:send(value)
					end
				end
			end)

			return self
		end

		print()
		print()

		local teed_r = Teed_R(r)
		local p1 = teed_r:clone()
		local p2 = teed_r:clone()

		h:spawn_later(500, function() w:write("hi") end)
		h:spawn_later(1000, function() w:write("hi") end)

		print(p1.ev:recv())
		print(p2.ev:recv())

		print(p1.ev:recv())
		print(p2.ev:recv())
	end,
}
