local ffi = require("ffi")
local C = ffi.C

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
		local buf = d.buffer(4096)

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
		local got = levee.json.decode(levee.json.encode(want))
		assert.same(want, got)
	end,

	test_encode_empty_table = function()
		assert.equal(levee.json.encode({}), "{}")
	end
}
