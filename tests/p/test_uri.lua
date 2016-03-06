
local URI = require("levee.p.uri")

return {
	test_segment = function()
		local err, uri = URI("http://user:pass@test.com:80/some/path?a=b#c")
		assert.is_nil(err)
		assert.equal("http", uri.scheme)
		assert.equal("user", uri.user)
		assert.equal("pass", uri.password)
		assert.equal("test.com", uri.host)
		assert.equal("80", uri.port)
		assert.equal("/some/path", uri.path)
		assert.equal("a=b", uri.query)
		assert.equal("c", uri.fragment)
		assert.equal("user:pass", uri.userinfo)
		assert.equal("user:pass@test.com:80", uri.authority)
		assert.equal("user:pass@test.com:80/some/path", uri.hierarch)
		assert.equal("/some/path?a=b", uri.request)

		local err, params = uri:params()
		assert.is_nil(err)
		assert.same({a="b"}, params)
	end,

	test_sub = function()
		local err, uri = URI("http://user:pass@test.com:80/some/path?a=b#c")
		assert.is_nil(err)
		assert.equal("http://user:pass@test.com:80", uri:sub(URI.SCHEME, URI.PORT))
		assert.equal("test.com:80/some/path?a=b", uri:sub(URI.HOST, URI.QUERY))

		-- the range has to back up to make a valid URI
		assert.equal("//user:pass@test.com:80/some/path?a=b", uri:sub(URI.HOST, URI.QUERY, true))

		assert.equal("a=b", uri:sub(URI.QUERY))

		-- the range has to back up to make a valid URI
		assert.equal("?a=b", uri:sub(URI.QUERY, true))
	end,

	test_join_string = function()
		local err, uri = URI("http://user:pass@test.com:80/some/path?a=b#c")
		assert.is_nil(err)

		local err, join = uri:join("https://new.com/new/path")
		assert.is_nil(err)
		assert.equal("https://new.com/new/path", tostring(join))

		local err, join = uri:join("//new.com/new/path")
		assert.is_nil(err)
		assert.equal("http://user:pass@new.com/new/path", tostring(join))

		local err, join = uri:join("/new/path")
		assert.is_nil(err)
		assert.equal("http://user:pass@test.com:80/new/path", tostring(join))

		local err, join = uri:join("/../sibling")
		assert.is_nil(err)
		assert.equal("http://user:pass@test.com:80/sibling", tostring(join))

		local err, join = uri:join("?a=1")
		assert.is_nil(err)
		assert.equal("http://user:pass@test.com:80/some/path?a=1", tostring(join))
	end,

	test_join_uri = function()
		local err, uri = URI("http://user:pass@test.com:80/some/path?a=b#c")
		assert.is_nil(err)

		local err, other = URI("http://new.com/new/path")
		assert.is_nil(err)
		local err, join = uri:join(other)
		assert.is_nil(err)
		assert.equal("http://new.com/new/path", join.value)

		local err, other = URI("//new.com/new/path")
		assert.is_nil(err)
		local err, join = uri:join(other)
		assert.is_nil(err)
		assert.equal("http://user:pass@new.com/new/path", join.value)

		local err, other = URI("/new/path")
		assert.is_nil(err)
		local err, join = uri:join(other)
		assert.is_nil(err)
		assert.equal("http://user:pass@test.com:80/new/path", join.value)

		local err, other = URI("/../sibling")
		assert.is_nil(err)
		local err, join = uri:join(other)
		assert.is_nil(err)
		assert.equal("http://user:pass@test.com:80/sibling", join.value)

		local err, other = URI("?a=1")
		assert.is_nil(err)
		local err, join = uri:join(other)
		assert.is_nil(err)
		assert.equal("http://user:pass@test.com:80/some/path?a=1", join.value)
	end,

	test_params = function()
		local err, uri = URI("?x=1&value=123&x=2&text=some+words+%F0%9F%91%8C%20&x=3")
		assert.is_nil(err)

		local err, params = uri:params()
		assert.equal("123", params.value)
		assert.equal("some words 👌 ", params.text)
		assert.same({"1","2","3"}, params.x)
	end
}
