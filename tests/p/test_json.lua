local ffi = require("ffi")
local C = ffi.C

local _ = require("levee._")
local d = require("levee.d")
local p = require("levee.p")


return {
	test_core = function()
		local decoder = p.json.decoder()

		local err, n = decoder:next("}{", 2, false)
		assert(err)

		decoder:reset()

		local err, n = decoder:next("{}", 2, false)
		assert(not err)
		assert.equal(n, 1)
		assert.equal(decoder.type, C.SP_JSON_OBJECT)
		assert(not decoder:is_done())

		local err, n = decoder:next("}", 1, false)
		assert(not err)
		assert.equal(n, 1)
		assert.equal(decoder.type, C.SP_JSON_OBJECT_END)
		assert(decoder:is_done())

		local err, n = decoder:next("{}", 2, false)
		assert(err)

		decoder:reset()
		local err, n = decoder:next("{}", 2, false)
		assert(not err)
	end,

	test_stream = function()
		-- stream stub
		local buf = d.Buffer(4096)

		local stream = {
			segments = {
				'{"int": 3, "f',
				'oo": "bar", "neste',
				'd": {"null": null, "alist": ',
				'[1, 2, 3], "yes": tr',
				'ue, "no": false}}{',
				'"foo": "bar"}}', }}
		stream.__index = stream

		function stream:readin()
			local s = table.remove(self.segments, 1)
			if not s then
				return -1
			end
			buf:push(s)
			return nil, #s
		end

		function stream:value()
			return buf:value()
		end

		function stream:trim(n)
			return buf:trim(n)
		end
		--
		
		local decoder = p.json.decoder()

		local err, value = decoder:stream(stream)
		assert(not err)
		assert.same(value, {
			int = 3,
			foo = "bar",
			nested = {
				alist = {1, 2, 3},
				yes = true,
				no = false, } })

		local err, value = decoder:stream(stream)
		assert(not err)
		assert.same(value, {foo = "bar"})

		local err, value = decoder:stream(stream)
		assert(err)
	end,

	test_decode = function()
		local err, value = p.json.decode('{"foo": "bar"}')
		assert(not err)
		assert.same(value, {foo="bar"})
		local err, value = p.json.decode('}{')
		assert(err)
	end,

	test_encode = function()
		local want = {"a", 1, "b", {foo="bar\nfoo"}}
		local err, buf = p.json.encode(want)
		local s = buf:take()
		assert.equal(s, '["a", 1, "b", {"foo": "bar\\nfoo"}]')
		local err, got = p.json.decode(s)
		assert.same(want, got)
	end,

	test_encode_empty_table = function()
		local err, buf = p.json.encode({})
		assert.equal(buf:take(), "{}")
	end,

	test_encode_escape = function()
		local want = {key=[[\n\t\+=-/%.&}{"'👻]]}
		local err, buf = p.json.encode(want)
		local err, got = p.json.decode(buf:value())
		assert.same(want, got)

		-- pathological case
		local want = {key=(('"'):rep(4096))}
		local err, buf = p.json.encode(want)
		local err, got = p.json.decode(buf:value())
		assert.same(want, got)
	end,

	test_encode_bad_utf8 = function()
		local filename = debug.getinfo(1, 'S').source:sub(2)
		local path = _.path.dirname(filename)
		local fh = io.open(path.."/bad_utf8")
		local s = fh:read("*all")
		fh:close()

		local err, buf = p.json.encode(s)
		assert(err)
		local err, buf = p.json.encode({foo = s})
		assert(err)
	end,

	test_more = function()
		local want = {
			params = {
							h = "50",
							w = "100" },
			uri = "/1/5376404c0d42e0472e0784aa:100/gA/:/i2.jpg",
			foo = {},
			headers = {
							Accept = "*/*",
							["User-Agent"] = "levee/0.3.2-alpha",
							Host = "cgraphics.imgix.net" } }
		local err, buf = p.json.encode(want)
		local err, got = p.json.decoder():stream(buf)
		assert.same(got, want)
	end,
}
