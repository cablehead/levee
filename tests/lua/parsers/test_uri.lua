local ffi = require("ffi")
local C = ffi.C

local parsers = require("levee.parsers")

return {
	test_sub = function()
		local parser = parsers.uri.URI()
		local value = "http://user:pass@test.com:80/some/path?a=b#c"
		local i, j

		assert(parser:parse(value))

		i, j = parser:sub(parsers.uri.scheme, parsers.uri.port)
		assert.equal("http://user:pass@test.com:80", value:sub(i, j))

		i, j = parser:sub(parsers.uri.host, parsers.uri.query)
		assert.equal("test.com:80/some/path?a=b", value:sub(i, j))

		-- the range has to back up to make a valid URI
		i, j = parser:sub(parsers.uri.host, parsers.uri.query, true)
		assert.equal("//user:pass@test.com:80/some/path?a=b", value:sub(i, j))

		i, j = parser:sub(parsers.uri.query, parsers.uri.query)
		assert.equal("a=b", value:sub(i, j))

		-- the range has to back up to make a valid URI
		i, j = parser:sub(parsers.uri.query, parsers.uri.query, true)
		assert.equal("?a=b", value:sub(i, j))
	end,

	test_segment = function()
		local parser = parsers.uri.URI()
		local value = "http://user:pass@test.com:80/some/path?a=b#c"
		local i, j

		assert(parser:parse(value))

		i, j = parser:segment(parsers.uri.scheme)
		assert.equal("http", value:sub(i, j))

		i, j = parser:segment(parsers.uri.user)
		assert.equal("user", value:sub(i, j))

		i, j = parser:segment(parsers.uri.password)
		assert.equal("pass", value:sub(i, j))

		i, j = parser:segment(parsers.uri.host)
		assert.equal("test.com", value:sub(i, j))

		i, j = parser:segment(parsers.uri.port)
		assert.equal("80", value:sub(i, j))

		i, j = parser:segment(parsers.uri.path)
		assert.equal("/some/path", value:sub(i, j))

		i, j = parser:segment(parsers.uri.query)
		assert.equal("a=b", value:sub(i, j))

		i, j = parser:segment(parsers.uri.fragment)
		assert.equal("c", value:sub(i, j))
	end,

	test_join_string = function()
		local parser = parsers.uri.URI()
		local value = "http://user:pass@test.com:80/some/path?a=b#c"
		local join_parser, join_value

		assert(parser:parse(value))

		join_parser, join_value = parser:join_string(value, "http://new.com/new/path")
		assert.equal("http://new.com/new/path", join_value)

		join_parser, join_value = parser:join_string(value, "//new.com/new/path")
		assert.equal("http://user:pass@new.com/new/path", join_value)

		join_parser, join_value = parser:join_string(value, "/new/path")
		assert.equal("http://user:pass@test.com:80/new/path", join_value)

		join_parser, join_value = parser:join_string(value, "/../sibling")
		assert.equal("http://user:pass@test.com:80/sibling", join_value)

		join_parser, join_value = parser:join_string(value, "?a=1")
		assert.equal("http://user:pass@test.com:80/some/path?a=1", join_value)
	end,

	test_join_parser = function()
		local parser = parsers.uri.URI()
		local other = parsers.uri.URI()
		local value = "http://user:pass@test.com:80/some/path?a=b#c"
		local join_parser, join_value

		assert(parser:parse(value))

		other_val = "http://new.com/new/path"
		assert(other:parse(other_val))
		join_parser, join_value = parser:join_parser(value, other, other_val)
		assert.equal("http://new.com/new/path", join_value)

		other_val = "//new.com/new/path"
		assert(other:parse(other_val))
		join_parser, join_value = parser:join_parser(value, other, other_val)
		assert.equal("http://user:pass@new.com/new/path", join_value)

		other_val = "/new/path"
		assert(other:parse(other_val))
		join_parser, join_value = parser:join_parser(value, other, other_val)
		assert.equal("http://user:pass@test.com:80/new/path", join_value)

		other_val = "/../sibling"
		assert(other:parse(other_val))
		join_parser, join_value = parser:join_parser(value, other, other_val)
		assert.equal("http://user:pass@test.com:80/sibling", join_value)

		other_val = "?a=1"
		assert(other:parse(other_val))
		join_parser, join_value = parser:join_parser(value, other, other_val)
		assert.equal("http://user:pass@test.com:80/some/path?a=1", join_value)
	end
}
