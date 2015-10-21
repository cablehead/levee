local URI = require("levee.uri")

return {
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
	end
}
