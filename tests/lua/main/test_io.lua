local function x(s, n)
	ret = {}
	for _ = 1, n do
		table.insert(ret, s)
	end
	return table.concat(ret)
end


return {
	test_close_writer = function()
		local levee = require("levee")

		local h = levee.Hub()
		local r, w = h.io:pipe()

		w:write("foo")

		local buf = levee.buffer(4096)
		local n, err = r:read(buf:tail())
		buf:bump(n)
		assert.equal(buf:take_s(), "foo")

		w:close()

		local n, err = r:read(buf:tail())
		assert(n <= 0)
		assert(err > 0)

		local n, err = r:read(buf:tail())
		assert(n <= 0)
		assert(err > 0)

		assert.same(h.registered, {})
	end,

	test_last_read = function()
		local levee = require("levee")

		local h = levee.Hub()
		local r, w = h.io:pipe()

		w:write("foo")
		w:close()

		local buf = levee.buffer(4096)
		local n, err = r:read(buf:tail())
		buf:bump(n)
		assert.equal(buf:take_s(), "foo")

		local n, err = r:read(buf:tail())
		assert(n <= 0)
		assert(err > 0)

		assert.same(h.registered, {})
	end,

	test_close_reader = function()
		local levee = require("levee")

		local h = levee.Hub()
		local r, w = h.io:pipe()

		r:close()

		-- continue is required to flush the close
		h:continue()

		local n, err = w:write("foo")
		assert(n <= 0)
		assert(err > 0)

		local n, err = w:write("foo")
		assert(n <= 0)
		assert(err > 0)
	end,

	test_readinto = function()
		local levee = require("levee")

		local h = levee.Hub()
		local r, w = h.io:pipe()

		local buf = levee.buffer(4096)

		w:write("foo")

		local n, err = r:readinto(buf)
		assert.equal(buf:take_s(), "foo")

		w:close()

		local n, err = r:readinto(buf)
		assert(n <= 0)
		assert(err > 0)

		assert.same(h.registered, {})
	end,

	test_writev = function()
		local levee = require("levee")
		local iov = levee.iovec.Iovec(32)

		local h = levee.Hub()
		local r, w = h.io:pipe()

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

		h:spawn(function()
			w:writev(iov.iov, iov.n)
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
	end,

	test_iov = function()
		local levee = require("levee")

		local h = levee.Hub()
		local r, w = h.io:pipe()

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

		local buf = levee.buffer(4096)
		while true do
			local rc = r:readinto(buf)
			if rc < 0 then break end
		end

		assert.equal(#want, #buf)
		assert.equal(want, buf:take_s())
	end,

	test_timeout = function()
		local levee = require("levee")

		local h = levee.Hub()
		local r, w = h.io:pipe(20)

		local buf = levee.buffer(4096)
		local got = r:read(buf:tail())
		assert.equal(got, levee.TIMEOUT)
	end,

	test_stream = function()
		local levee = require("levee")

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
	end,
}
