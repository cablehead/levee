local levee = require("levee")


return {
	test_core = function()

		-- stream stub
		local buf = levee.buffer(4096)
		local stream = {
			segments = {
				'{"int": 3, "f',
				'oo": "bar", "neste',
				'd": {"null": null, "alist": ',
				'[1, 2, 3], "yes": tr',
				'ue, "no": false}}{',
				'"foo": "bar"}', }}
		stream.__index = stream

		function stream:readin()
			local s = table.remove(self.segments, 1)
			if not s then
				return -1
			end
			buf:push_s(s)
			return #s
		end

		function stream:value()
			return buf:value()
		end

		function stream:trim(n)
			return buf:trim(n)
		end
		--

		local parser = levee.json.decoder()

		local ok, got = parser:stream_consume(stream)
		assert(ok)
		assert.same(got, {
			int = 3,
			foo = "bar",
			nested = {
				alist = {1, 2, 3},
				yes = true,
				no = false, } })

		local ok, got = parser:stream_consume(stream)
		assert(ok)
		assert.same(got, {foo = "bar"})

		local ok, got = parser:stream_consume(stream)
		assert(not ok)
	end,

	test_decode = function()
		local s = '{"foo": "bar"}'
		local got = levee.json.decode(s)
		assert.same(got, {foo="bar"})
	end,

	test_encode = function()
		local want = {"a", 1, "b", {foo="bar"}}
		local got = levee.json.decode(levee.json.encode(want))
		assert.same(want, got)
	end,

	test_encode_empty_table = function()
		assert.equal(levee.json.encode({}), "{}")
	end
}
