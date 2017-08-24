local ffi = require('ffi')
local C = ffi.C

local levee = require("levee")
local _ = levee._
local d = levee.d


local CHARS64 =
	"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"


return {
	core = {
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
			assert(not h:in_use())
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
			assert(not h:in_use())
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
			assert(not h:in_use())
		end,

		test_reads = function()
			local h = levee.Hub()

			local r, w = h.io:pipe()
			w:write("foo")
			assert.equal(r:reads(), "foo")
			w:close()
			assert.equal(r:reads(), nil)
			assert(not h:in_use())
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

		test_sendfile = function()
			local h = levee.Hub()

			local tmp = _.path.Path:tmpdir()
			defer(function() tmp:remove(true) end)

			local path = tostring(tmp("foo"))
			tmp("foo"):write(("x"):rep(8192*1024))

			local err, serve = h.stream:listen()
			local err, addr = serve:addr()
			local err, c = h.stream:dial(addr:port())
			local err, s = serve:recv()

			local err, r1 = h.io:open(path)
			local err, st = r1:stat()

			local buf = d.Buffer()
			h:spawn(function() s:readinto(buf, st.st_size) end)

			local err, n = r1:sendfile(c, st.st_size)
			assert(not err)
			assert.equal(n, st.st_size)

			h:sleep(10)
			assert.equal(buf:take(), ("x"):rep(8192*1024))
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
			assert(not h:in_use())
		end,
	},

	stream = {
		test_core = function()
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

		test_read = function()
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

		test_readn = function()
			local h = levee.Hub()

			local r, w = h.io:pipe()

			local s = r:stream()
			local buf = levee.d.Buffer(4096)

			w:write(("."):rep(10))
			s:readin()
			w:write(("."):rep(5))

			local check
			h:spawn(function() check = {s:readn(buf:tail(), 20, 20)} end)
			assert.equal(check, nil)

			w:write(("."):rep(10))
			assert.same(check, {nil, 20})
			buf:bump(20)
			assert.equal(buf:take(), ("."):rep(20))

			s:readin()
			assert.equal(s:take(), ("."):rep(5))
		end,

		test_readinto = function()
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

		test_json = function()
			local h = levee.Hub()

			local r, w = h.io:pipe()
			local s = r:stream()

			w:write([[{"foo": "bar"}]])
			local err, data = s:json()
			assert.same(data, {foo = "bar"})

			w:write([[{"foo": "bar"}]])
			local err, data = s:json()
			assert.same(data, {foo = "bar"})
		end,

		test_msgpack = function()
			local h = levee.Hub()

			local r, w = h.io:pipe()
			local s = r:stream()

			w:send_msgpack({foo = "bar"})
			local err, data = s:msgpack()
			assert.same(data, {foo = "bar"})

			w:send_msgpack({foo = "bar"})
			local err, data = s:msgpack()
			assert.same(data, {foo = "bar"})
		end,
	},

	chunk = {
		test_core = function()
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

		test_tobuffer = function()
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

		test_discard = function()
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

		test_json = function()
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
	},

	splice = {
		test_small = function()
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

		test_big = function()
			local pre = ("."):rep(10)
			local val = CHARS64:rep(512)
			local crc = C.sp_crc32c(0ULL, pre, #pre)
			crc = C.sp_crc32c(crc, val, #val)
			crc = C.sp_crc32c(crc, val, #val)
			crc = C.sp_crc32c(crc, val, #val)
			crc = C.sp_crc32c(crc, val, #val - 10)
			local N = 64 * 512 * 4

			local h = levee.Hub()

			local p1 = {}
			p1.r, p1.w = h.io:pipe()
			p1.s = p1.r:stream()

			local p2 = {}
			p2.r, p2.w = h.io:pipe()
			p2.s = p2.r:stream()

			-- setup thread to drain p2
			local drained = (function()
				local sender, recver = h:pipe()
				h:spawn(function()
					h:sleep(100)   -- add a pause so the splice's write side fills up
					p2.s:readin(N)
					sender:close()
				end)
				return recver
			end)()

			-- buffer a few bytes ahead of splice
			p1.w:write(pre)
			p1.s:readin()

			-- write main payload
			h:spawn(function()
				p1.w:write(val)
				p1.w:write(val)
				p1.w:write(val)
				p1.w:write(val)
			end)

			p1.c = p1.s:chunk(N)
			assert.same({p1.c:splice(p2.w)}, {nil, N})
			p1.c.done:recv()
			drained:recv()
			assert.equal(#p2.s.buf, N)

			assert.equal(C.sp_crc32c(0ULL, p2.s:value()), crc)
			assert.equal(p1.s:take(10), "23456789+/")

			p1.r:close()
			p1.w:close()
			p2.r:close()
			p2.w:close()

			assert(not h:in_use())
		end,

		test_error_on_read = function()
			local val = CHARS64:rep(4096)
			local crc = C.sp_crc32c(0ULL, val, #val)
			local N = 64 * 4096

			local h = levee.Hub()

			local p1 = {}
			p1.r, p1.w = h.io:pipe()
			p1.s = p1.r:stream()

			local p2 = {}
			p2.r, p2.w = h.io:pipe()
			p2.s = p2.r:stream()

			h:spawn(function() assert.equal(p2.s:readin(N), levee.errors.CLOSED) end)
			-- drop write half way through
			h:spawn(function() p1.w:write(val, N/2) ; p1.w:close() end)

			p1.c = p1.s:chunk(N)
			assert.equal(p1.c:splice(p2.w), levee.errors.CLOSED)

			p2.r:close()
			p2.w:close()
			h:continue()
			assert(not h:in_use())
		end,

		test_error_on_write = function()
			local val = CHARS64:rep(4096)
			local crc = C.sp_crc32c(0ULL, val, #val)
			local N = 64 * 4096

			local h = levee.Hub()

			local p1 = {}
			p1.r, p1.w = h.io:pipe()
			p1.s = p1.r:stream()

			local p2 = {}
			p2.r, p2.w = h.io:pipe()
			p2.s = p2.r:stream()

			-- drop read half way through
			h:spawn(function() p2.s:readin(N/4); p2.r:close() end)
			h:spawn(function()
				local err = p1.w:write(val, N)
				assert(not err)
				p1.w:close()
			end)

			p1.c = p1.s:chunk(N)
			local err = p1.c:splice(p2.w)
			assert(err)
			p2.w:close()

			h:continue()

			local want = #p1.c
			local __, len = p1.c:value()
			assert.equal(len, 0)

			p1.c:readin(want)
			local __, len = p1.c:value()
			assert.equal(len, want)

			assert.equal(p1.s:readin(), levee.errors.CLOSED)

			assert(not h:in_use())
		end,

		test_tcp = function()
			local h = levee.Hub()

			local data = ("."):rep(200000)

			local err, serve = h.tcp:listen()
			local err, addr = serve:addr()
			local port = addr:port()

			local err, c1 = h.tcp:connect(port)
			local err, s1 = serve:recv()
			local err, c2 = h.tcp:connect(port)
			local err, s2 = serve:recv()

			local stream = s2:stream()

			h:spawn(function()
				while true do
					local err = c1:write(("."):rep(10000))
					if err then break end
					h:sleep(2)
				end
			end)

			s1:stream():chunk(#data):splice(c2)
			assert.equal(stream:take(#data), data)

			s1:stream():chunk(#data):splice(c2)
			assert.equal(stream:take(#data), data)

			s1:stream():chunk(#data):splice(c2)
			assert.equal(stream:take(#data), data)

			s1:close()
			c2:close()
			s2:close()
			serve:close()
			h:sleep(10)

			assert(not h:in_use())
		end,
	},

	tee = {
		test_small_spawned = function()
			local h = levee.Hub()

			local source = {}
			source.r, source.w = h.io:pipe()
			source.s = source.r:stream()

			local t1 = {}
			t1.r, t1.w = h.io:pipe()
			local t2 = {}
			t2.r, t2.w = h.io:pipe()

			-- buffer some bytes
			source.w:write(("."):rep(10))
			source.s:readin()

			source.w:write(("."):rep(20))

			source.c = source.s:chunk(20)
			local check = ""
			assert.same(
				{source.c:tee(t1.w, t2.w, function(chunks)
					for chunk in chunks do
						check = check .. chunk:tostring()
					end
				end)},
				{nil, 20})

			assert.same(t1.r:reads(), ("."):rep(20))
			assert.same(t2.r:reads(), ("."):rep(20))
			assert.same(check, ("."):rep(20))

			assert.equal(source.s:take(), ("."):rep(10))

			source.r:close()
			source.w:close()
			t1.r:close()
			t1.w:close()
			t2.r:close()
			t2.w:close()

			assert(not h:in_use())
		end,

		test_small_spliced = function()
			local h = levee.Hub()

			local source = {}
			source.r, source.w = h.io:pipe()
			source.s = source.r:stream()

			local t1 = {}
			t1.r, t1.w = h.io:pipe()
			local t2 = {}
			t2.r, t2.w = h.io:pipe()
			local t3 = {}
			t3.r, t3.w = h.io:pipe()

			-- buffer some bytes
			source.w:write(("."):rep(10))
			source.s:readin()

			source.w:write(("."):rep(20))

			source.c = source.s:chunk(20)
			assert.same({source.c:tee(t1.w, t2.w, t3.w)}, {nil, 20})

			assert.same(t1.r:reads(), ("."):rep(20))
			assert.same(t2.r:reads(), ("."):rep(20))
			assert.same(t3.r:reads(), ("."):rep(20))

			assert.equal(source.s:take(), ("."):rep(10))

			source.r:close()
			source.w:close()
			t1.r:close()
			t1.w:close()
			t2.r:close()
			t2.w:close()
			t3.r:close()
			t3.w:close()

			assert(not h:in_use())
		end,

		test_big_spawned = function()
			local pre = ("."):rep(10)
			local val = CHARS64:rep(512)
			local crc = C.sp_crc32c(0ULL, pre, #pre)
			crc = C.sp_crc32c(crc, val, #val)
			crc = C.sp_crc32c(crc, val, #val)
			crc = C.sp_crc32c(crc, val, #val)
			crc = C.sp_crc32c(crc, val, #val - 10)
			local N = 64 * 512 * 4

			local h = levee.Hub()

			local source = {}
			source.r, source.w = h.io:pipe()
			source.s = source.r:stream()

			local function teer()
				local t = {}
				t.r, t.w = h.io:pipe()
				t.s = t.r:stream()
				h:spawn(function()
					while true do
						if t.s:readin() then break end
					end
				end)
				return t
			end

			local t1 = teer()
			local t2 = teer()

			-- buffer some bytes
			source.w:write(("."):rep(10))
			source.s:readin()

			-- main writer
			h:spawn(function()
				source.w:write(val)
				source.w:write(val)
				source.w:write(val)
				source.w:write(val)
			end)

			source.c = source.s:chunk(N)
			local check
			assert.same(
				{source.c:tee(t1.w, t2.w, function(chunks)
					local err
					for chunk in chunks do
						err, check = chunk:tobuffer(check)
					end
				end)},
				{nil, N})

			assert.equal(C.sp_crc32c(0ULL, t1.s:value()), crc)
			assert.equal(C.sp_crc32c(0ULL, t2.s:value()), crc)
			assert.equal(C.sp_crc32c(0ULL, check:value()), crc)
			assert.equal(source.s:take(10), "23456789+/")

			source.r:close()
			source.w:close()
			t1.r:close()
			t1.w:close()
			t2.r:close()
			t2.w:close()

			assert(not h:in_use())
		end,

		test_big_splice = function()
			local pre = ("."):rep(10)
			local val = CHARS64:rep(512)
			local crc = C.sp_crc32c(0ULL, pre, #pre)
			crc = C.sp_crc32c(crc, val, #val)
			crc = C.sp_crc32c(crc, val, #val)
			crc = C.sp_crc32c(crc, val, #val)
			crc = C.sp_crc32c(crc, val, #val - 10)
			local N = 64 * 512 * 4

			local h = levee.Hub()

			local source = {}
			source.r, source.w = h.io:pipe()
			source.s = source.r:stream()

			local function teer()
				local t = {}
				t.r, t.w = h.io:pipe()
				t.s = t.r:stream()
				h:spawn(function()
					while true do
						if t.s:readin() then break end
					end
				end)
				return t
			end

			local t1 = teer()
			local t2 = teer()
			local t3 = teer()

			-- buffer some bytes
			source.w:write(("."):rep(10))
			source.s:readin()

			-- main writer
			h:spawn(function()
				source.w:write(val)
				source.w:write(val)
				source.w:write(val)
				source.w:write(val)
			end)

			source.c = source.s:chunk(N)
			assert.same({source.c:tee(t1.w, t2.w, t3.w)}, {nil, N})
			h:continue()

			assert.equal(C.sp_crc32c(0ULL, t1.s:value()), crc)
			assert.equal(C.sp_crc32c(0ULL, t2.s:value()), crc)
			assert.equal(C.sp_crc32c(0ULL, t3.s:value()), crc)
			assert.equal(source.s:take(10), "23456789+/")

			source.r:close()
			source.w:close()
			t1.r:close()
			t1.w:close()
			t2.r:close()
			t2.w:close()
			t3.r:close()
			t3.w:close()

			assert(not h:in_use())
		end,
	},

	p = {
		test_core = function()
			local h = levee.Hub()

			local r, w = h.io:pipe()
			assert(r.p.rbuf)
			assert(w.p.wbuf)
			assert(not r.p.wbuf)
			assert(not w.p.rbuf)
		end,
	},
}
