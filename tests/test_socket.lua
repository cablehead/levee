return {
	test_core = function()
		local Socket = require("levee.sys.socket")
		local Endpoint = require("levee.sys.endpoint")
		local l, err = Socket:listen(12345, "127.0.0.1")
		local c, err = Socket:connect(12345, "127.0.0.1")
		assert(l ~= nil)
		assert(c ~= nil)
		local le, err = Endpoint:sockname(l.base.no)
		local ce, err = Endpoint:peername(c.base.no)
		assert(tostring(le) == tostring(ce))
	end,
}
