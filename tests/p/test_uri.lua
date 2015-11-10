
local p = require("levee.p")

return {
	test_sub = function()
		local parser = p.uri.URI()
		local value = "http://user:pass@test.com:80/some/path?a=b#c"
		local i, j

		assert(parser:parse(value))

		i, j = parser:sub(p.uri.scheme, p.uri.port)
		assert.equal("http://user:pass@test.com:80", value:sub(i, j))

		i, j = parser:sub(p.uri.host, p.uri.query)
		assert.equal("test.com:80/some/path?a=b", value:sub(i, j))

		-- the range has to back up to make a valid URI
		i, j = parser:sub(p.uri.host, p.uri.query, true)
		assert.equal("//user:pass@test.com:80/some/path?a=b", value:sub(i, j))

		i, j = parser:sub(p.uri.query, p.uri.query)
		assert.equal("a=b", value:sub(i, j))

		-- the range has to back up to make a valid URI
		i, j = parser:sub(p.uri.query, p.uri.query, true)
		assert.equal("?a=b", value:sub(i, j))
	end,

	test_segment = function()
		local parser = p.uri.URI()
		local value = "http://user:pass@test.com:80/some/path?a=b#c"
		local i, j

		assert(parser:parse(value))

		i, j = parser:segment(p.uri.scheme)
		assert.equal("http", value:sub(i, j))

		i, j = parser:segment(p.uri.user)
		assert.equal("user", value:sub(i, j))

		i, j = parser:segment(p.uri.password)
		assert.equal("pass", value:sub(i, j))

		i, j = parser:segment(p.uri.host)
		assert.equal("test.com", value:sub(i, j))

		i, j = parser:segment(p.uri.port)
		assert.equal("80", value:sub(i, j))

		i, j = parser:segment(p.uri.path)
		assert.equal("/some/path", value:sub(i, j))

		i, j = parser:segment(p.uri.query)
		assert.equal("a=b", value:sub(i, j))

		i, j = parser:segment(p.uri.fragment)
		assert.equal("c", value:sub(i, j))
	end,

	test_join_string = function()
		local parser = p.uri.URI()
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
		local parser = p.uri.URI()
		local other = p.uri.URI()
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
	end,

--[[
	-- TODO: higher level URI tests
	test_segments = function()
		local u = URI("http://user:pass@test.com:80/some/path?a=b#c")
		assert(u)
		assert.equal("http", u.scheme)
		assert.equal("user", u.user)
		assert.equal("pass", u.password)
		assert.equal("test.com", u.host)
		assert.equal("80", u.port)
		assert.equal("/some/path", u.path)
		assert.equal("a=b", u.query)
		assert.equal("c", u.fragment)
		assert.equal("user:pass", u.userinfo)
		assert.equal("user:pass@test.com:80", u.authority)
	end,

	test_join_string = function()
		local u = URI("http://user:pass@test.com:80/some/path?a=b#c")
		local join

		assert(u)

		join = u:join("http://new.com/new/path")
		assert.equal("http://new.com/new/path", join.value)

		join = u:join("//new.com/new/path")
		assert.equal("http://user:pass@new.com/new/path", join.value)

		join = u:join("/new/path")
		assert.equal("http://user:pass@test.com:80/new/path", join.value)

		join = u:join("/../sibling")
		assert.equal("http://user:pass@test.com:80/sibling", join.value)

		join = u:join("?a=1")
		assert.equal("http://user:pass@test.com:80/some/path?a=1", join.value)
	end,

	test_join_parser = function()
		local u = URI("http://user:pass@test.com:80/some/path?a=b#c")
		local other, join

		assert(u)

		other = URI("http://new.com/new/path")
		assert(other)
		join = u:join(other)
		assert.equal("http://new.com/new/path", join.value)

		other = URI("//new.com/new/path")
		assert(other)
		join = u:join(other)
		assert.equal("http://user:pass@new.com/new/path", join.value)

		other = URI("/new/path")
		assert(other)
		join = u:join(other)
		assert.equal("http://user:pass@test.com:80/new/path", join.value)

		other = URI("/../sibling")
		assert(other)
		join = u:join(other)
		assert.equal("http://user:pass@test.com:80/sibling", join.value)

		other = URI("?a=1")
		assert(other)
		join = u:join(other)
		assert.equal("http://user:pass@test.com:80/some/path?a=1", join.value)
	end,
--]]
}
