local d = require("levee.d")
local line = require("levee.p.line")


local function Stream()
	local buf = d.Buffer(4096)

	local stream = {
		segments = {
			'foo\r\n',
			'bar',
			'123\r\n',
			'last\r',
			'\n', }}
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

	return stream
end


return {
	test_slash_n = function()
		local stream = Stream()
		assert.same({line.stream(stream)}, {nil, "foo\r"})
		assert.same({line.stream(stream)}, {nil, "bar123\r"})
		assert.same({line.stream(stream)}, {nil, "last\r"})
		assert.same({line.stream(stream)}, {-1})
	end,

	test_slash_r_slash_n = function()
		local stream = Stream()
		assert.same({line.stream(stream, "\r\n")}, {nil, "foo"})
		assert.same({line.stream(stream, "\r\n")}, {nil, "bar123"})
		assert.same({line.stream(stream, "\r\n")}, {nil, "last"})
		assert.same({line.stream(stream, "\r\n")}, {-1})
	end,
}
