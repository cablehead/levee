local _ = require("levee")._


return {
	test_basic = function()
		local base = _.version("v1.2.9")
		assert(base ~= nil)
		assert(base:is_compatible("v1.x"))
		assert(base:is_compatible("v1.2"))
		assert(base:is_compatible("v1.2.x"))
		assert(base:is_compatible("v1.2.9"))
		assert(not base:is_compatible("v1.2.8"))
		assert(not base:is_compatible("v1.3.9"))
		assert(not base:is_compatible("v1.3.x"))
	end,

	test_beta = function()
		local beta = _.version("v1.3.0-beta.1")
		assert(beta ~= nil)
		assert(beta:is_compatible("v1.3.0-beta"))
		assert(beta:is_compatible("v1.3.0-beta.x"))
		assert(beta:is_compatible("v1.3.0-beta.1"))
		assert(not beta:is_compatible("v1.3.0-beta.2"))
		assert(not beta:is_compatible("v1.3.1-beta.1"))
		assert(not beta:is_compatible("v1.3.0"))
	end,

	test_string = function()
		assert.same("v1.x.x", tostring(_.version("1")))
		assert.same("v1.x.x", tostring(_.version("1.x")))
		assert.same("v1.x.x", tostring(_.version("1.x.x")))
		assert.same("v1.2.x", tostring(_.version("1.2")))
		assert.same("v1.2.x", tostring(_.version("1.2.x")))
		assert.same("v1.2.3", tostring(_.version("1.2.3")))
		assert.same("v1.2.3-beta.x", tostring(_.version("1.2.3-beta")))
		assert.same("v1.2.3-beta.x", tostring(_.version("1.2.3-beta.x")))
		assert.same("v1.2.3-beta.1", tostring(_.version("1.2.3-beta.1")))
		assert.same("v1.x.x", tostring(_.version("v1")))
		assert.same("v1.x.x", tostring(_.version("v1.x")))
		assert.same("v1.x.x", tostring(_.version("v1.x.x")))
		assert.same("v1.2.x", tostring(_.version("v1.2")))
		assert.same("v1.2.x", tostring(_.version("v1.2.x")))
		assert.same("v1.2.3", tostring(_.version("v1.2.3")))
		assert.same("v1.2.3-beta.x", tostring(_.version("v1.2.3-beta")))
		assert.same("v1.2.3-beta.x", tostring(_.version("v1.2.3-beta.x")))
		assert.same("v1.2.3-beta.1", tostring(_.version("v1.2.3-beta.1")))
	end,

	test_bump = function()
		local v = _.version("v1.2.3")
		assert.same("v1.2.4-alpha.1", tostring(v:bump("pre_release")))
		assert.same("v1.2.4", tostring(v:bump("patch")))
		assert.same("v1.3.0", tostring(v:bump("minor")))
		assert.same("v2.0.0", tostring(v:bump("major")))
		assert.same("v1.2.4", tostring(v:bump()))
	end,

	test_bump_pre_release = function()
		local v = _.version("v1.2.3-foo.4")
		assert.same("v1.2.3-foo.5", tostring(v:bump("pre_release")))
		assert.same("v1.2.4", tostring(v:bump("patch")))
		assert.same("v1.3.0", tostring(v:bump("minor")))
		assert.same("v2.0.0", tostring(v:bump("major")))
		assert.same("v1.2.3-foo.5", tostring(v:bump()))
	end
}
